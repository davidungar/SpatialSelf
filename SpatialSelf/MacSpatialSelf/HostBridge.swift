//
//  HostBridge.swift
//  MacSpatialSelf — macOS host for the Self VM (host-bridge E.2).
//
//  The macOS end of the Swift<->VM host bridge. Owns two pipes:
//    • event pipe   (app -> VM):  app writes length-prefixed event frames
//    • present pipe (VM -> app):  VM writes length-prefixed present frames
//  Frame = 4-byte little-endian length + payload — symmetric with the Self side
//  in objects/hostBridge.self. Responses are surfaced on the main actor.
//
//  -- claude & dmu 5/26
//

import Foundation
import Observation

@MainActor
@Observable
final class HostBridge {

    /// Latest count the VM has presented back (the trivial E.2 handler increments it).
    private(set) var count: Int = 0

    // fds the VM binds (it shares our process fd table; passed via --bridge-* flags):
    nonisolated let vmEventReadFD: Int32      // VM reads events here
    nonisolated let vmPresentWriteFD: Int32   // VM writes present frames here

    // fds the app keeps:
    private let eventWriteFD: Int32           // app writes events here
    private let presentReadFD: Int32          // app reads present frames here

    private var source: DispatchSourceRead?
    private var inbox = Data()

    init() {
        var ev = [Int32](repeating: -1, count: 2)   // ev[0]=read, ev[1]=write
        var pr = [Int32](repeating: -1, count: 2)
        precondition(pipe(&ev) == 0 && pipe(&pr) == 0, "host-bridge pipe() failed")
        vmEventReadFD   = ev[0]; eventWriteFD  = ev[1]
        presentReadFD   = pr[0]; vmPresentWriteFD = pr[1]
        startReadingPresent()
    }

    /// Send one event frame to the VM. Payload is arbitrary; the E.2 handler just counts.
    func postEvent(_ payload: Data = Data([0x54 /* 'T' */])) {
        writeFrame(payload, to: eventWriteFD)
    }

    /// Self boot code fed to the VM over stdin once it has booted: install the real
    /// `selectInto:` (snapshots still carry the stdin-only stub), bind hostBridge to our
    /// fds, and fork its `watch` pump. `hostBridge` itself is filed in via `-f` (see launcher).
    nonisolated var bootScript: String {
        """
        os _AddSlots: ( | selectInto: sv MaxFiles: m IfFail: fb = ( while_EINTR_do: [ |:e| basicSelectInto: sv asVector Size: m IfFail: e ] IfFail: fb ). | ).
        hostBridge bindEventFd: \(vmEventReadFD) PresentFd: \(vmPresentWriteFD).
        (message copy receiver: hostBridge Selector: 'watch') fork resume.

        """
    }

    // MARK: - framing

    private func writeFrame(_ payload: Data, to fd: Int32) {
        var frame = Data(capacity: 4 + payload.count)
        let n = UInt32(payload.count)
        frame.append(UInt8(n & 0xff));         frame.append(UInt8((n >> 8) & 0xff))
        frame.append(UInt8((n >> 16) & 0xff));  frame.append(UInt8((n >> 24) & 0xff))
        frame.append(payload)
        frame.withUnsafeBytes { raw in
            var off = 0
            while off < raw.count {
                let w = write(fd, raw.baseAddress!.advanced(by: off), raw.count - off)
                if w <= 0 { break }
                off += w
            }
        }
    }

    private func startReadingPresent() {
        let fd = presentReadFD
        let src = DispatchSource.makeReadSource(fileDescriptor: fd, queue: .global(qos: .userInitiated))
        src.setEventHandler { [weak self] in
            var buf = [UInt8](repeating: 0, count: 4096)
            let n = read(fd, &buf, buf.count)
            guard n > 0 else { return }
            let chunk = Data(buf[0..<n])
            Task { @MainActor in self?.ingest(chunk) }
        }
        source = src
        src.resume()
    }

    /// Accumulate bytes and decode complete 4-byte-LE-length frames; the E.2 present
    /// payload is a 4-byte LE count.
    private func ingest(_ chunk: Data) {
        inbox.append(chunk)
        while inbox.count >= 4 {
            let len = Int(inbox[inbox.startIndex])
                | (Int(inbox[inbox.startIndex + 1]) << 8)
                | (Int(inbox[inbox.startIndex + 2]) << 16)
                | (Int(inbox[inbox.startIndex + 3]) << 24)
            guard inbox.count >= 4 + len else { break }
            let payload = inbox.subdata(in: (inbox.startIndex + 4)..<(inbox.startIndex + 4 + len))
            inbox.removeSubrange(inbox.startIndex..<(inbox.startIndex + 4 + len))
            if payload.count >= 4 {
                count = Int(payload[payload.startIndex])
                    | (Int(payload[payload.startIndex + 1]) << 8)
                    | (Int(payload[payload.startIndex + 2]) << 16)
                    | (Int(payload[payload.startIndex + 3]) << 24)
            }
        }
    }
}

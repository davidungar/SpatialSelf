//
//  TerminalOutputRedirector.swift
//  Self_1
//

import Foundation
import SwiftUI
import Views
import DavesUtilities

// MARK: - Terminal Output Redirector

#if true

class Terminal_IO_Redirector {
  // Must retain dispatch sources or they get cancelled on dealloc.
  private var sources: [any DispatchSourceRead] = []

  /// File descriptors for each output stream.
  private var fdsByOutputStream: [OutputStream: Int32] = [:]

  /// Stdin pipe: Self reads from `stdinReadFD`; the UI writes to `_stdinWriteFD`.
  private(set) var stdinReadFD:  Int32? = nil
  private      var _stdinWriteFD: Int32 = -1

  // MARK: - Output batching
  // Accumulate (color, text) pairs on a serial queue and flush to the
  // main thread at most once per `flushInterval` to avoid flooding the
  // main run-loop during heavy output.

  private let batchQueue = DispatchQueue(label: "terminal.batch")
  private var pendingChunks: [(Color, String)] = []
  private var flushScheduled = false
  private let flushInterval: TimeInterval = 0.05  // 50 ms

  /// Enqueue text; the batch queue coalesces and flushes periodically.
  private func enqueue(_ text: String, color: Color) {
    batchQueue.async { [self] in
      pendingChunks.append((color, text))
      guard !flushScheduled else { return }
      flushScheduled = true
      batchQueue.asyncAfter(deadline: .now() + flushInterval) { [self] in
        let chunks = pendingChunks
        pendingChunks.removeAll(keepingCapacity: true)
        flushScheduled = false
        DispatchQueue.main.async {
          for (c, t) in chunks {
            TerminalModel.shared.write(t, color: c)
          }
        }
      }
    }
  }

  /// Look up the write-end fd for a given stream.
  func outputFD(for stream: OutputStream) -> Int32 {
    fdsByOutputStream[stream] ?? STDOUT_FILENO
  }

  /// Legacy accessor — returns the selfStdout fd.
  var terminalFD: Int32 {
    outputFD(for: .selfStdout)
  }

  /// Write a line of text into the stdin pipe so Self code can read it.
  func writeToStdin(_ string: String) {
    guard _stdinWriteFD >= 0 else { return }
    let line = string + "\n"
    line.toUInt8Array.withContiguousStorageIfAvailable { buf in
      let c = Darwin.write(_stdinWriteFD, buf.baseAddress, buf.count)
    }
  }

  /// Create one pipe per output stream.  Call once at app launch.
  func start() {
    for stream in OutputStream.allCases.excluding(.stdout) {
      fdsByOutputStream[stream] = makeTerminalPipe(stream: stream)
    }

    // Create the stdin pipe — read end for Self, write end for the UI.
    var stdinPipe = [Int32](repeating: 0, count: 2)
    if pipe(&stdinPipe) == 0 {
      stdinReadFD   = stdinPipe[0]
      _stdinWriteFD = stdinPipe[1]
    }
    else {fatalError()}
    
    // keep real stdout/stderr for OS-generated cruft
#if false
    // needs updating for multiple streams
    // Also redirect real stdout/stderr so Swift print() reaches the terminal.
    redirect(fd: STDOUT_FILENO)
    redirect(fd: STDERR_FILENO)
    // Force unbuffered so every write reaches the pipe immediately.
    setvbuf(stdout, nil, _IONBF, 0)
    setvbuf(stderr, nil, _IONBF, 0)
    #endif
  }
  
  private  func redirect(fd: Int32) {
    var pipeFDs = [Int32](repeating: 0, count: 2)
    guard pipe(&pipeFDs) == 0 else { return }
    let readFD  = pipeFDs[0]

    // Replace the file descriptor with the write end of the pipe.
    dup2(pipeFDs[1], fd)
    close(pipeFDs[1])
    
    // Replace the file descriptor with the write end of the pipe.
    dup2(pipeFDs[1], fd)
    close(pipeFDs[1])

    // Make the read end non-blocking isn't needed; DispatchSource handles it.
    let source = DispatchSource.makeReadSource(fileDescriptor: readFD, queue: .global(qos: .userInteractive))
    source.setEventHandler { [self] in
      let bufSize = 4096
      let buf = UnsafeMutablePointer<UInt8>.allocate(capacity: bufSize)
      defer { buf.deallocate() }
      let n = read(readFD, buf, bufSize)
      guard n > 0 else { return }
      let str = String(bytes: UnsafeBufferPointer(start: buf, count: n), encoding: .utf8)
              ?? String(bytes: UnsafeBufferPointer(start: buf, count: n), encoding: .ascii)
              ?? ""
      enqueue(str, color: .primary)
    }
    source.resume()
    sources.append(source)
  }

  /// Create a pipe whose read end forwards to TerminalModel with `color`.
  /// Returns the write-end file descriptor (non-blocking).
  private func makeTerminalPipe(stream: OutputStream) -> Int32 {
    let color = stream.color
    var pipeFDs = [Int32](repeating: 0, count: 2)
    guard pipe(&pipeFDs) == 0 else { return STDOUT_FILENO }
    let readFD  = pipeFDs[0]
    let writeFD = pipeFDs[1]

    // Make write-end non-blocking so the interpreter thread never stalls
    // waiting for the main thread to drain the pipe.
    let flags = fcntl(writeFD, F_GETFL)
    if flags >= 0 { _ = fcntl(writeFD, F_SETFL, flags | O_NONBLOCK) }

    let src = DispatchSource.makeReadSource(fileDescriptor: readFD, queue: .global(qos: .userInteractive))
    src.setEventHandler { [self] in
      let bufSize = 4096
      let buf = UnsafeMutablePointer<UInt8>.allocate(capacity: bufSize)
      defer { buf.deallocate() }
      let n = read(readFD, buf, bufSize)
      guard n > 0 else { return }
      let str = String(bytes: UnsafeBufferPointer(start: buf, count: n), encoding: .utf8)
              ?? String(bytes: UnsafeBufferPointer(start: buf, count: n), encoding: .ascii)
              ?? ""
      enqueue(str, color: color)
    }
    src.resume()
    sources.append(src)
    return writeFD
  }
  func redirectedFD(for fd: Int32) -> Int32 {
    switch fd {
    case STDIN_FILENO:   stdinReadFD!
    case STDOUT_FILENO:  outputFD(for: .selfStdout)
    case STDERR_FILENO:  outputFD(for: .selfStderr)
    default: fd
    }
  }
  func selfFD(for redirectedFD: Int32) -> Int32 {
    switch redirectedFD {
    case stdinReadFD!:   STDIN_FILENO
    case outputFD(for: .selfStdout): STDOUT_FILENO
    case outputFD(for: .selfStderr): STDERR_FILENO
    default: redirectedFD
    }
  }
}

#endif

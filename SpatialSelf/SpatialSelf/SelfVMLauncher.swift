//
//  SelfVMLauncher.swift
//  SpatialSelf
//
//  Owns the Terminal_IO_Redirector pipes, hands their fds to the statically
//  linked Self VM via self_vm_set_io_fds(), then spawns a detached thread
//  that calls self_vm_main(). Stdin written by TerminalView reaches the VM
//  through the redirector's writeToStdin() bridge.
//
//  Self.framework is linked statically (via SelfVM.xcframework in the target's
//  Frameworks build phase) — see notes in `../self64/vm64`
//  about the heap-at-24GB / timer-off requirements that make this safe on
//  visionOS.
//

import Foundation
import SwiftUI  // for Color in error messages
import Views    // ReusableViews — TerminalModel
import Darwin

final class SelfVMLauncher {
  static let shared = SelfVMLauncher()

  let io = Terminal_IO_Redirector<OutputStream> {TerminalModel.shared.write($0, color: $1)}
  private var started = false

  /// Launch the VM. If `snapshotPath` is non-nil, the VM reads its initial
  /// world from that file (passed as `-s <path>`); otherwise it boots fresh.
  func start(snapshotPath: String? = nil) {
    guard !started else { return }
    started = true

    let m = TerminalModel.shared
    m.writeLine("Welcome to the terminal.")
    m.writeLine("Type something and press Return.")

    TerminalModel.shared.onSubmit = { [io] line in
      io.writeToStdin(line)
    }
    let stdinFD  = io.stdinReadFD
    let stdoutFD = io.outputFD(for: OutputStream.selfStdout)
    let stderrFD = io.outputFD(for: OutputStream.selfStderr)

    Thread.detachNewThread { [weak self] in
      Thread.current.name = "Self VM"

      self_vm_set_io_fds(stdinFD, stdoutFD, stderrFD)

      // No "-t": the VM now redirects timer signals to its own thread
      // (IntervalTimerTick / self_vm_timer_thread in itimer_unix.cpp), so
      // setitimer no longer jams the SwiftUI host and preemption stays on.
      let args = ["Self"]
      + (snapshotPath.map { ["-s", $0] } ?? []) // read initial world from the chosen snapshot
      + CommandLine.arguments.dropFirst() // pass any extra argv down to the VM
      var argv: [UnsafeMutablePointer<CChar>?] = args.map { $0.withCString { strdup($0) } } + [nil]
      let toFree = argv
      defer { for p in toFree { if let p { free(p) } } }
      let argc = Int32(args.count)
      argv.withUnsafeMutableBufferPointer { buf in
        _ = self_vm_main(argc, buf.baseAddress)
      }
      _ = self
    }
  }
}

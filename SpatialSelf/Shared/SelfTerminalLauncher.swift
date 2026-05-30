//
//  SelfTerminalLauncher.swift
//  SpatialSelf (Shared) — interactive terminal launcher for both hosts.
//
//  Owns the Terminal_IO_Redirector pipes, hands their fds to the statically linked
//  Self VM (via SelfVM.launch), then the VM runs on a detached thread. Stdin typed
//  into TerminalView reaches the VM through the redirector's writeToStdin() bridge;
//  the VM's stdout/stderr come back through the redirector into TerminalModel.
//
//  The VM reads its initial world from `snapshotPath` once at init (passed as
//  `-s <path>`), or boots fresh when nil. See ../README.md for the heap-at-24GB /
//  timer-off requirements that make running the VM in-process safe.
//

import Foundation
import SwiftUI  // for Color in error messages
import Views    // ReusableViews — TerminalModel
import Darwin

final class SelfTerminalLauncher {
  static let shared = SelfTerminalLauncher()

  let io = Terminal_IO_Redirector<OutputStream> {TerminalModel.shared.write($0, color: $1)}
  private(set) var started = false

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

    // No "-t": the VM now redirects timer signals to its own thread
    // (IntervalTimerTick / self_vm_timer_thread in itimer_unix.cpp), so
    // setitimer no longer jams the SwiftUI host and preemption stays on.
    let args = ["Self"]
//       + ["-t"]
    + (snapshotPath.map { ["-s", $0] } ?? []) // read initial world from the chosen snapshot
    + CommandLine.arguments.dropFirst()       // pass any extra argv down to the VM

    SelfVM.launch(threadName: "Self VM",
                  stdin:  io.stdinReadFD,
                  stdout: io.outputFD(for: OutputStream.selfStdout),
                  stderr: io.outputFD(for: OutputStream.selfStderr),
                  args:   args)
  }
}

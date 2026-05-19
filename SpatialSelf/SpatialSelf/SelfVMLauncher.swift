//
//  SelfVMLauncher.swift
//  SpatialSelf
//
//  Owns the Terminal_IO_Redirector pipes, hands their fds to the VM via
//  self_vm_set_io_fds(), then spawns a detached thread that calls
//  self_vm_main(). Stdin written by TerminalView reaches the VM through
//  the redirector's writeToStdin() bridge.
//

import Foundation
import Views   // ReusableViews — TerminalModel
import Darwin

final class SelfVMLauncher {
  static let shared = SelfVMLauncher()

  let io = Terminal_IO_Redirector()
  private var started = false

  func start() {
    guard !started else { return }
    started = true

    let m = TerminalModel.shared
    m.writeLine("Welcome to the terminal.")
    m.writeLine("Type something and press Return.")

#if true // SPATIALSELF_LINK_VM
    io.start()
    Task { @MainActor in
      TerminalModel.shared.onSubmit = { [io] line in
        io.writeToStdin(line)
      }
    }

    let stdinFD  = io.stdinReadFD ?? -1
    let stdoutFD = io.outputFD(for: .selfStdout)
    let stderrFD = io.outputFD(for: .selfStderr)
    self_vm_set_io_fds(stdinFD, stdoutFD, stderrFD)

    Thread.detachNewThread { [weak self] in
      Thread.current.name = "Self VM"
      var argv0 = strdup("Self")!
      defer { free(argv0) }
      withUnsafeMutablePointer(to: &snort/*argv0*/) { p in
        let argv = UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>(OpaquePointer(p))
        _ = self_vm_main(1, argv)
      }
      _ = self
    }
#else
    m.writeLine("[A/B TEST: Self VM not linked]")
#endif
  }
}

var snort = "Self VM snort"

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

// #if false

  let io = Terminal_IO_Redirector()
//   #endif
  private var started = false

  func start() {
    guard !started else { return }
    started = true
    
    let m = TerminalModel.shared
    m.writeLine("Welcome to the terminal.")
    m.writeLine("Type something and press Return.")
//    let line = await m.readLine()
//    m.writeLine("You typed: \(line)")

 
    io.start()

    // Wire TerminalView submits into the VM's stdin pipe.
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
      _ = self  // keep launcher alive for the VM's lifetime
    }

  }
}

var snort = "Self VM snort"

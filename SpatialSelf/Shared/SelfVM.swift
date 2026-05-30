//
//  SelfVM.swift
//  SpatialSelf (Shared) — the de-duplicated Self VM launch core.
//
//  Both hosts (the visionOS/macOS terminal and the macOS host-bridge test) start
//  the statically linked Self VM the same way: hand it its three io fds via
//  self_vm_set_io_fds(), then run self_vm_main() on a fresh detached thread with a
//  C argv it owns. This wraps exactly that boilerplate so each launcher only has to
//  supply its fds and args (and do its own pre/post wiring).
//
//  Only ONE self_vm_main may run per process: the VM keeps fixed global state (heap
//  mmap'd at a fixed address, signal handlers, a single VM thread), so callers gate
//  launch behind a singleton `started` flag. -- claude & dmu 5/26
//

import Foundation

enum SelfVM {
  /// Hand the VM its io fds and run self_vm_main() on a fresh detached thread.
  /// `args` is the full argv including argv[0] ("Self"); it is copied with strdup
  /// and freed when self_vm_main() returns.
  static func launch(threadName: String,
                     stdin: Int32, stdout: Int32, stderr: Int32,
                     args: [String]) {
    Thread.detachNewThread {
      Thread.current.name = threadName

      self_vm_set_io_fds(stdin, stdout, stderr)

      var argv: [UnsafeMutablePointer<CChar>?] = args.map { $0.withCString { strdup($0) } } + [nil]
      let toFree = argv
      defer { for p in toFree { if let p { free(p) } } }
      argv.withUnsafeMutableBufferPointer { buf in
        _ = self_vm_main(Int32(args.count), buf.baseAddress)
      }
    }
  }
}

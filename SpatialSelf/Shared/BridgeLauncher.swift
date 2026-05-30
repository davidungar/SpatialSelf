//
//  BridgeLauncher.swift
//  SpatialSelf (Shared) — host-bridge (E.2) launcher. macOS-only.
//
//  Launches the headless Self VM (linked statically from libSelfVM) on a
//  background thread, and stands up the host bridge: the VM reads a snapshot (-s),
//  files in objects/hostBridge.self (-f), and is told its two bridge fds. We then
//  feed a short boot script over the VM's stdin to install the real selectInto:,
//  bind hostBridge to those fds, and fork its watch pump.
//
//  macOS-only: the snapshot / source paths below are hard-coded to this machine's
//  self64 checkout, which only exists on the dev Mac (not in a visionOS sandbox).
//  (A snapshot boots the scheduler with no windows by default, so the headless VM
//  is happy.)
//
//  -- claude & dmu 5/26
//

#if os(macOS)

import Foundation

@MainActor
final class BridgeLauncher {
    static let shared = BridgeLauncher()
    let bridge = HostBridge()
    private var started = false

    private let self64 = "\(NSHomeDirectory())/self/vms/OurSelf/self64"

    func start() {
        guard !started else { return }
        started = true

        let snapshot       = "\(self64)/A.snap"
        let hostBridgeSelf = "\(self64)/objects/hostBridge.self"

        // stdin pipe so we can feed the bridge boot script after the world boots.
        var sin = [Int32](repeating: -1, count: 2)   // sin[0] = VM read end, sin[1] = app write end
        precondition(pipe(&sin) == 0, "stdin pipe() failed")
        let vmStdinRead = sin[0], appStdinWrite = sin[1]

        // VM reads our stdin; stdout/stderr -> console (-1 leaves them on the tty).
        // The fd numbers are conveyed to the VM by the boot script (literal
        // `hostBridge bindEventFd:PresentFd:` fed over stdin), so no --bridge-* argv
        // flags are needed here.
        SelfVM.launch(threadName: "Self VM (mac)",
                      stdin: vmStdinRead, stdout: -1, stderr: -1,
                      args: ["Self", "-s", snapshot, "-f", hostBridgeSelf])

        // Feed the boot script. It's buffered in the pipe; the VM's REPL consumes it
        // after the snapshot loads and postRead runs (boot is sequential).
        let boot = bridge.bootScript
        boot.withCString { _ = write(appStdinWrite, $0, strlen($0)) }
    }
}

#endif

//
//  SpatialSelfApp.swift
//  SpatialSelf — visionOS host for the Self VM.
//
//  Owns a TerminalView window, pipes stdin/stdout/stderr into the C++
//  Self VM (linked via Self.xcframework from ~/self/vms/OurSelf/self64),
//  and launches the VM on a background thread.
//

import SwiftUI
import Views      // ReusableViews — TerminalView, TerminalModel

@main
struct SpatialSelfApp: App {
  var body: some Scene {
    WindowGroup {
      SelfShellView()
      
        .task {
          // Defer VM launch until after SwiftUI presents the window.
          // The Self VM installs handlers for SIGSEGV/SIGBUS/SIGILL/SIGTRAP
          // which UIKit + RealityKit use during init; starting earlier
          // hangs the main thread in fatal_menu.
          SelfVMLauncher.shared.start()
        }
    }
    .defaultSize(width: 900, height: 1050)
  }
}

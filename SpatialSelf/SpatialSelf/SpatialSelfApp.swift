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
  init() {
    // Start the VM as early as possible to test whether the .task deferral
    // is still load-bearing now that heap@24GB and -t are in place.
    SelfVMLauncher.shared.start()
  }

  var body: some Scene {
    WindowGroup {
      SelfShellView()
    }
    .defaultSize(width: 900, height: 1050)
  }
}

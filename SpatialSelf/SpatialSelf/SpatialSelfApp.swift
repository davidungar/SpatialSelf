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
  // The VM is no longer started here: SelfShellView shows a start screen so the
  // user can choose a snapshot (or start fresh) before the VM boots, since the
  // VM reads its snapshot only once, during initialization.
  var body: some Scene {
    WindowGroup {
      MacRootView()
    }
    .defaultSize(width: 900, height: 1050)
  }
}


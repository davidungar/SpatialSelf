//
//  SelfApp.swift
//  SpatialSelf (Shared) — entry point for both hosts.
//
//  One @main App, compiled into each target (visionOS and macOS) as its own
//  module, so both products share the same window + root. SelfRootView shows the
//  terminal by default; on macOS it also offers the E.2 host-bridge test.
//

import SwiftUI

@main
struct SelfApp: App {
  var body: some Scene {
    WindowGroup {
      SelfRootView()
    }
    .defaultSize(width: 900, height: 1050)
  }
}

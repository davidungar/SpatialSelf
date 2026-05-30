//
//  MacSpatialSelfApp.swift
//  MacSpatialSelf — macOS host for the Self VM.
//
//  Shows the terminal shell by default (the same SelfShellView the visionOS app
//  uses), with the E.2 host-bridge test reachable from MacRootView.
//

import SwiftUI

@main
struct MacSpatialSelfApp: App {
    var body: some Scene {
        WindowGroup {
            MacRootView()
        }
        .defaultSize(width: 900, height: 1050)
    }
}

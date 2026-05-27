//
//  MacSpatialSelfApp.swift
//  MacSpatialSelf — macOS host for the Self VM (host-bridge E.2).
//
//  Shows the bridge test window; the VM + bridge are started from
//  BridgeTestView.onAppear (so the launch runs on the main actor).
//

import SwiftUI

@main
struct MacSpatialSelfApp: App {
    var body: some Scene {
        WindowGroup {
            BridgeTestView()
        }
        .defaultSize(width: 380, height: 240)
    }
}

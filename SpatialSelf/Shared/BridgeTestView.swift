//
//  BridgeTestView.swift
//  SpatialSelf (Shared) — host-bridge (E.2) frontend. macOS-only.
//
//  A "tick" button sends an event frame to the Self VM, and the count reflects what
//  hostBridge presents back. Reads BridgeLauncher.shared.bridge inside `body` (which
//  SwiftUI runs on the main actor) so @Observable tracks `count`.
//

#if os(macOS)

import SwiftUI

struct BridgeTestView: View {
    var body: some View {
        let bridge = BridgeLauncher.shared.bridge
        VStack(spacing: 20) {
            Text("Self host bridge (E.2)").font(.headline)
            Text("count from VM: \(bridge.count)")
                .font(.system(.largeTitle, design: .monospaced))
            Button("tick") { bridge.postEvent() }
                .keyboardShortcut(.defaultAction)
            Text("Each tap sends an event frame to the VM; the count is what hostBridge presents back.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(minWidth: 340, minHeight: 200)
        .onAppear { BridgeLauncher.shared.start() }
    }
}

#Preview {
    BridgeTestView()
}

#endif

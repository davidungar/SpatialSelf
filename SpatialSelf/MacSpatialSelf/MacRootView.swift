//
//  MacRootView.swift
//  MacSpatialSelf
//
//  Root of the macOS host. Defaults to the same terminal shell the visionOS app
//  shows (SelfShellView), and offers the E.2 host-bridge test as an alternative
//  reached from a button under the start screen.
//
//  Only one Self VM can run per process (it keeps fixed global state), so the two
//  modes are mutually exclusive: once the terminal boots, SelfShellView swaps to
//  TerminalView and the bridge button is gone; choosing the bridge instead boots
//  the bridge VM. The choice is therefore made before any VM starts.
//

import SwiftUI

struct MacRootView: View {
  private enum Mode {
    case terminal,
         bridge
  }

  @State private var mode: Mode = .terminal

  var body: some View {
    switch mode {
    case .terminal:
      SelfShellView {
        Button("Bridge test (E.2)…") { mode = .bridge }
          .padding(.top, 8)
      }
    case .bridge:
      BridgeTestView()   // launches MacSelfLauncher.start() on appear
    }
  }
}

#Preview {
  MacRootView()
}

//
//  SelfRootView.swift
//  SpatialSelf (Shared) — root of both hosts.
//
//  Shows the terminal shell (SelfShellView). On macOS it also offers the E.2
//  host-bridge test as an alternative reached from a button under the start
//  screen; the bridge is macOS-only, so on visionOS this is just the terminal.
//
//  Only one Self VM can run per process (it keeps fixed global state), so the two
//  modes are mutually exclusive: once the terminal boots, SelfShellView swaps to
//  TerminalView and the bridge button is gone; choosing the bridge instead boots
//  the bridge VM. The choice is therefore made before any VM starts.
//

import SwiftUI
import Views   // ReusableViews — showingTypeName

struct SelfRootView: View {
  private enum Mode {
    case terminal
#if os(macOS)
    case bridge
#endif
  }

  @State private var mode: Mode = .terminal

  var body: some View {
    Group {
      switch mode {
      case .terminal:
        SelfShellView { bridgeButton }
#if os(macOS)
      case .bridge:
        BridgeTestView()   // launches BridgeLauncher.start() on appear
#endif
      }
    }
    .showingTypeName(Self.self)
  }

  /// The "open the bridge test" affordance, shown beneath the start screen on
  /// macOS only. On visionOS this builds to nothing, leaving a plain terminal.
  @ViewBuilder private var bridgeButton: some View {
#if os(macOS)
    Button("Bridge test (E.2)…") { mode = .bridge }
      .padding(.top, 8)
#endif
  }
}

#Preview {
  SelfRootView()
}

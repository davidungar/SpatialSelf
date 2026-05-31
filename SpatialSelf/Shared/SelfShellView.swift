//
//  SelfShellView.swift
//  SpatialSelf
//
//  Routes between the launch screen (choose a snapshot or start fresh) and the
//  running terminal. The VM reads its snapshot only once at init, so the choice
//  must be made before SelfTerminalLauncher.start() runs.
//

import SwiftUI
import Views

struct SelfShellView<Accessory: View>: View {
  @State private var vmStarted = false
  @ViewBuilder private let accessory: () -> Accessory

  /// `accessory` is shown beneath the start screen (before the VM boots) — used by
  /// the macOS host to offer the E.2 bridge test. It defaults to nothing, so the
  /// visionOS host just writes `SelfShellView()`.
  init(@ViewBuilder accessory: @escaping () -> Accessory = { EmptyView() }) {
    self.accessory = accessory
  }

  var body: some View {
    VStack(spacing: 0) {
      if vmStarted {
        TerminalView()
        Divider()
        SelfRunningControls()
      } else {
        SnapshotLaunchView(onChoose: { snapshotPath in
          SelfTerminalLauncher.shared.start(snapshotPath: snapshotPath)
          vmStarted = true
        }, accessory: accessory)
      }
    }
  }
}

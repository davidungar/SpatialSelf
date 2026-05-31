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
  /// The launch screen is content-sized (the window hugs its button row), but the terminal is
  /// an open-ended scroll region with no intrinsic content size to derive from — so we pick a
  /// comfortable default for the window to open at once the VM boots. Not magic: an intentional
  /// "first run" size; the user can resize freely afterward.
  private static var terminalDefaultSize: CGSize { CGSize(width: 900, height: 1050) }

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
    // Once the VM boots, give the content-sized window the terminal's default size; before
    // that the launch screen hugs its button row (no dead space, no number needed).
    .frame(idealWidth:  vmStarted ? Self.terminalDefaultSize.width  : nil,
           idealHeight: vmStarted ? Self.terminalDefaultSize.height : nil)
  }
}

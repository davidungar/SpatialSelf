//
//  SelfShellView.swift
//  SpatialSelf
//
//  Routes between the launch screen (choose a snapshot or start fresh) and the
//  running terminal. The VM reads its snapshot only once at init, so the choice
//  must be made before SelfVMLauncher.start() runs.
//

import SwiftUI
import Views

struct SelfShellView: View {
  @State private var vmStarted = false

  var body: some View {
    VStack(spacing: 0) {
      if vmStarted {
        TerminalView()
      } else {
        SnapshotStartView { snapshotPath in
          SelfVMLauncher.shared.start(snapshotPath: snapshotPath)
          vmStarted = true
        }
      }
    }
  }
}

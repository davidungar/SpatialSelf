//
//  SnapshotStartView.swift
//  SpatialSelf
//
//  Launch screen: let the user pick a Self snapshot to load, or start a fresh
//  world. A picked file is copied into the app sandbox (Application Support)
//  while its security scope is held, and the resulting stable path is handed
//  back via `onChoose`. `onChoose(nil)` means "start fresh".
//

import SwiftUI
import Views                 // ReusableViews — FileSelectionView
import DavesUtilities        // CodableURLWithSecurityScope, whileAccessingOniOS
import UniformTypeIdentifiers

struct SnapshotStartView: View {
  /// Called with the staged snapshot path, or nil to start fresh.
  let onChoose: (String?) -> Void

  @State private var err: Error?
  @State private var staging = false

  var body: some View {
    VStack(spacing: 24) {
      Text("Self")
        .font(.largeTitle)
      Text("Choose a snapshot to load, or start a fresh world.")
        .foregroundStyle(.secondary)

      if staging {
        ProgressView("Loading snapshot…")
      } else {
        FileSelectionView(
          isFileSelectorPresented: false,
          buttonLabel: "Open snapshot…",
          fileDialogMessage: "Choose a Self snapshot to load",
          fileDialogConfirmationLabel: "Open",
          allowedContentTypes: [.data],   // snapshots have no registered UTType
          err: $err
        ) { group in
          if let picked = group.files.first { stageAndLaunch(picked) }
        }

        Button("Start fresh") { onChoose(nil) }
      }

      if let err {
        Text("Could not open snapshot: \(err.localizedDescription)")
          .foregroundStyle(.red)
      }
    }
    .padding(40)
  }

  private func stageAndLaunch(_ picked: CodableURLWithSecurityScope) {
    staging = true
    err = nil
    Task.detached {
      do {
        let path = try Self.stagedSnapshotPath(from: picked)
        await MainActor.run { onChoose(path) }
      } catch {
        await MainActor.run {
          self.err = error
          self.staging = false
        }
      }
    }
  }

  /// Copy the picked file into Application Support/Snapshots and return its
  /// absolute path. The copy runs while the file's security scope is held.
  private static func stagedSnapshotPath(from picked: CodableURLWithSecurityScope) throws -> String {
    guard let src = try picked.urlFromBookmark() else {
      throw CocoaError(.fileNoSuchFile)
    }
    let dir = try FileManager.default.url(for: .applicationSupportDirectory,
                                          in: .userDomainMask,
                                          appropriateFor: nil,
                                          create: true)
      .appendingPathComponent("Snapshots", isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let dst = dir.appendingPathComponent(src.lastPathComponent)
    try src.whileAccessingOniOS {
      if FileManager.default.fileExists(atPath: dst.path) {
        try FileManager.default.removeItem(at: dst)
      }
      try FileManager.default.copyItem(at: src, to: dst)
    }
    return dst.path   // absolute; the VM's -s accepts absolute paths
  }
}

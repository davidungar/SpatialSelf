//
//  SelfRunningControls.swift
//  SpatialSelf (Shared) — developer affordances shown beneath the running terminal.
//
//  Two buttons that drive the running VM over its stdin (via SelfTerminalLauncher.send):
//    • Save snapshot…  — prompt a name, then save the world to the host's writable snapshot
//                         dir (Mac: self64, so it becomes the next launch's newest; visionOS:
//                         the app sandbox — pull it back over the strap).
//    • File out changed — file out only the dirty modules (decision D3).
//

import SwiftUI

struct SelfRunningControls: View {
  private let catalog = SnapshotCatalog.current
  @State private var showSaveSheet = false
  @State private var saveName      = ""

  var body: some View {
    HStack(spacing: 12) {
      Button("Save snapshot…")  { presentSaveSheet() }
      Button("File out changed") { SelfTerminalLauncher.shared.send(SelfCommands.fileOutChangedModules) }
      Spacer()
    }
    .padding(.horizontal, 8)
    .padding(.vertical,   6)
    .sheet(isPresented: $showSaveSheet) { saveSheet }
  }

  // MARK: - Save sheet

  private var saveSheet: some View {
    VStack(spacing: 16) {
      Text("Save snapshot").font(.headline)
      TextField("name", text: $saveName)
        .textFieldStyle(.roundedBorder)
        .frame(minWidth: 240)
      Text("→ \(catalog.savePath(forBaseName: saveName.isEmpty ? "snapshot" : saveName))")
        .font(.caption.monospaced()).foregroundStyle(.secondary).lineLimit(1).truncationMode(.head)
      HStack {
        Button("Cancel", role: .cancel) { showSaveSheet = false }
        Button("Save") { saveSnapshot() }
          .keyboardShortcut(.defaultAction)
          .disabled(saveName.trimmingCharacters(in: .whitespaces).isEmpty)
      }
    }
    .padding(24)
  }

  // MARK: - Actions

  private func presentSaveSheet() {
    saveName = "" // could suggest a name from the launched snapshot later
    showSaveSheet = true
  }

  private func saveSnapshot() {
    let path = catalog.savePath(forBaseName: saveName.trimmingCharacters(in: .whitespaces))
    SelfTerminalLauncher.shared.send(SelfCommands.saveSnapshot(toPath: path))
    showSaveSheet = false
  }
}

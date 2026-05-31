//
//  SnapshotLaunchView.swift
//  SpatialSelf (Shared) — the default launch screen.
//
//  Decision D1: auto-pick the newest snapshot, show its name, and offer an override menu
//  (other snapshots in the catalog / open an arbitrary file / start fresh). Always shows a
//  staleness banner when filed-in `.self` source is newer than the chosen snapshot. The
//  "Open file…" override reuses SnapshotStartView (its picker stages into the sandbox).
//

import SwiftUI

struct SnapshotLaunchView: View {
  /// Called with the chosen snapshot path, or nil to start a fresh world.
  let onChoose: (String?) -> Void

  private let catalog = SnapshotCatalog.current
  @State private var entries:  [SnapshotCatalog.Entry] = []
  @State private var selected: SnapshotCatalog.Entry?
  @State private var staleness: SnapshotStaleness.Status = .fresh
  @State private var showFilePicker = false

  var body: some View {
    VStack(spacing: 20) {
      Text("Self").font(.largeTitle)
      if let selected { chosenSnapshot(selected) }
      else            { emptyState }
    }
    .padding(40)
    .onAppear      { reload() }
    .onChange(of: selected) { _, _ in refreshStaleness() }
    .sheet(isPresented: $showFilePicker) {
      SnapshotStartView(onChoose: onChoose)   // reuse: pick + stage + fresh
    }
  }

  // MARK: - Subviews

  @ViewBuilder private func chosenSnapshot(_ entry: SnapshotCatalog.Entry) -> some View {
    VStack(spacing: 6) {
      Text("Snapshot").font(.caption).foregroundStyle(.secondary)
      Text(entry.name).font(.title3.monospaced())
      if let warning = staleness.warning {
        Text(warning).font(.callout).foregroundStyle(.orange).multilineTextAlignment(.center)
      }
    }
    HStack(spacing: 12) {
      Button("Launch") { onChoose(entry.url.path) }
        .keyboardShortcut(.defaultAction)
      overrideMenu
    }
  }

  private var emptyState: some View {
    VStack(spacing: 12) {
      Text("No snapshots in \(catalog.snapshotsDir.path)")
        .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
      secondaryActions
    }
  }

  private var overrideMenu: some View {
    Menu("Other…") {
      ForEach(entries) { entry in
        Button { selected = entry } label: { Text(entry.name) }
      }
      Divider()
      secondaryActions
    }
  }

  /// Secondary launch choices — open an arbitrary snapshot file, or boot a fresh
  /// world. Shared by the empty state (inline buttons) and the "Other…" override
  /// menu so a new choice is added in exactly one place; a `Button` renders both
  /// inline and inside a `Menu`.
  @ViewBuilder private var secondaryActions: some View {
    Button("Open snapshot…")    { showFilePicker = true }
    Button("Start fresh world") { onChoose(nil) }
  }

  // MARK: - State

  private func reload() {
    entries  = catalog.entries()
    selected = entries.first
    refreshStaleness()
  }

  private func refreshStaleness() {
    staleness = selected.map { SnapshotStaleness.check(snapshot: $0.url, sourceRoot: catalog.sourceRoot) }
              ?? .fresh
  }
}

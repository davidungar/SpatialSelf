//
//  SnapshotLaunchView.swift
//  SpatialSelf (Shared) — the default launch screen.
//
//  Decision D1: auto-pick the newest snapshot. The newest gets its own "Launch <name>" button
//  in the top action row (alongside "Start without snapshot" and the host accessory, e.g. the
//  macOS bridge test). "Other snapshots…" opens the native file dialog directly, defaulting to
//  the snapshots directory (so the catalog is right there, sortable by date) but free to browse
//  anywhere; the picked file is staged into the sandbox by SnapshotCatalog. Always shows a
//  staleness banner when filed-in `.self` source is newer than the chosen snapshot.
//

import SwiftUI
import UniformTypeIdentifiers   // UTType

struct SnapshotLaunchView<Accessory: View>: View {
  /// Called with the chosen snapshot path, or nil to start a fresh world.
  let onChoose: (String?) -> Void

  /// Host-supplied control shown in the top action row (e.g. the macOS bridge test button).
  @ViewBuilder private let accessory: () -> Accessory

  init(onChoose: @escaping (String?) -> Void,
       @ViewBuilder accessory: @escaping () -> Accessory = { EmptyView() }) {
    self.onChoose  = onChoose
    self.accessory = accessory
  }

  private let catalog = SnapshotCatalog.current
  @State private var entries:  [SnapshotCatalog.Entry] = []
  @State private var selected: SnapshotCatalog.Entry?
  @State private var staleness: SnapshotStaleness.Status = .fresh
  @State private var showFilePicker = false
  @State private var pickerError: Error?

  var body: some View {
    VStack(spacing: 10) {
      Text("Self").font(.title2.bold())
      if let latest = entries.first { populated(latest) }
      else                          { emptyState }
      if let pickerError {
        Text("Could not open snapshot: \(pickerError.localizedDescription)")
          .font(.caption).foregroundStyle(.red).multilineTextAlignment(.center)
      }
    }
    .padding(16)
    .onAppear { reload() }
    .onChange(of: selected) { _, _ in refreshStaleness() }
    .fileImporter(isPresented:        $showFilePicker,
                  allowedContentTypes: [.data]) { result in   // snapshots have no registered UTType
      switch result {
      case .success(let url): stageAndLaunch(url)
      case .failure(let err): pickerError = err
      }
    }
    .fileDialogDefaultDirectory(catalog.snapshotsDir)   // land in the catalog; user can still browse out
  }

  // MARK: - Subviews

  @ViewBuilder private func populated(_ latest: SnapshotCatalog.Entry) -> some View {
    actionRow(latest)
    if let warning = staleness.warning {
      Text(warning).font(.caption).foregroundStyle(.orange).multilineTextAlignment(.center)
    }
    otherSnapshots
  }

  /// Top row: launch the newest snapshot, start fresh, and the host accessory.
  @ViewBuilder private func actionRow(_ latest: SnapshotCatalog.Entry) -> some View {
    HStack(spacing: 12) {
      Button("Launch \(latest.name)") { onChoose(latest.url.path) }
        .keyboardShortcut(.defaultAction)
      startWithoutSnapshotButton
      accessory()
    }
    .font(.callout)
  }

  private var emptyState: some View {
    VStack(spacing: 8) {
      Text("No snapshots in \(catalog.snapshotsDir.path)")
        .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
      HStack(spacing: 12) {
        startWithoutSnapshotButton
        otherSnapshots
        accessory()
      }
      .font(.callout)
    }
  }

  /// Boot the VM with no snapshot (a fresh world).
  private var startWithoutSnapshotButton: some View {
    Button("Start without snapshot") { onChoose(nil) }
  }

  /// Open the native file dialog directly to load any snapshot (defaults to the catalog dir).
  private var otherSnapshots: some View {
    Button("Other snapshots…") { showFilePicker = true }
      .font(.callout)
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

  /// Stage a snapshot picked from the file dialog into the sandbox, then launch it.
  private func stageAndLaunch(_ url: URL) {
    pickerError = nil
    do    { onChoose(try SnapshotCatalog.stageExternalSnapshot(at: url)) }
    catch { pickerError = error }
  }
}

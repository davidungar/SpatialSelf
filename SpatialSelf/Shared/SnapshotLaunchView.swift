//
//  SnapshotLaunchView.swift
//  SpatialSelf (Shared) — the default launch screen.
//
//  Decision D1: auto-pick the newest snapshot. The newest gets its own "Launch <name>" button
//  in the top action row (alongside "Start without snapshot" and the host accessory, e.g. the
//  macOS bridge test); the remaining snapshots appear below in a scrollable "Other snapshots"
//  list so any one can be launched with a single click. Always shows a staleness banner when
//  filed-in `.self` source is newer than the chosen snapshot. "Open snapshot…" reuses
//  SnapshotStartView (its picker stages into the sandbox) for snapshots outside the catalog.
//

import SwiftUI
import Views   // ReusableViews — showingTypeName

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

  /// How many of the "other" snapshots to surface inline before requiring "Open snapshot…".
  private static var visibleCount: Int { 7 }

  private let catalog = SnapshotCatalog.current
  @State private var entries:  [SnapshotCatalog.Entry] = []
  @State private var selected: SnapshotCatalog.Entry?
  @State private var staleness: SnapshotStaleness.Status = .fresh
  @State private var showFilePicker = false

  var body: some View {
    VStack(spacing: 10) {
      Text("Self").font(.title2.bold())
      if let latest = entries.first { populated(latest) }
      else                          { emptyState }
    }
    .padding(16)
    .onAppear      { reload() }
    .onChange(of: selected) { _, _ in refreshStaleness() }
    .sheet(isPresented: $showFilePicker) {
      SnapshotStartView(onChoose: onChoose)   // reuse: pick + stage + fresh
    }
    .showingTypeName(Self.self)
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
        .onHover { if $0 { selected = latest } }
      startWithoutSnapshotButton
      accessory()
    }
    .font(.callout)
  }

  /// The snapshots other than the newest — a single click launches any of them.
  @ViewBuilder private var otherSnapshots: some View {
    let others = Array(entries.dropFirst().prefix(Self.visibleCount))
    if !others.isEmpty {
      VStack(alignment: .leading, spacing: 4) {
        HStack {
          Text("Other snapshots").font(.caption).foregroundStyle(.secondary)
          Spacer()
          openSnapshotButton.font(.caption)
        }
        ScrollView {
          VStack(spacing: 2) {
            ForEach(others) { snapshotRow($0) }
          }
        }
        .frame(maxHeight: 160)
      }
    } else {
      openSnapshotButton.font(.callout)
    }
  }

  /// One snapshot row: tap to launch, hover highlight.
  private func snapshotRow(_ entry: SnapshotCatalog.Entry) -> some View {
    Button { onChoose(entry.url.path) } label: {
      Text(entry.name).font(.body.monospaced())
        .padding(.horizontal, 8).padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(entry == selected ? Color.accentColor.opacity(0.18) : .clear,
                    in: RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .onHover { if $0 { selected = entry } }
  }

  private var emptyState: some View {
    VStack(spacing: 8) {
      Text("No snapshots in \(catalog.snapshotsDir.path)")
        .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
      HStack(spacing: 12) {
        startWithoutSnapshotButton
        openSnapshotButton
        accessory()
      }
      .font(.callout)
    }
  }

  /// Boot the VM with no snapshot (a fresh world).
  private var startWithoutSnapshotButton: some View {
    Button("Start without snapshot") { onChoose(nil) }
  }

  /// Open an arbitrary snapshot file (staged into the sandbox) — for snapshots
  /// older than the visible list or outside the catalog.
  private var openSnapshotButton: some View {
    Button("Open snapshot…") { showFilePicker = true }
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

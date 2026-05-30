//
//  SnapshotCatalog.swift
//  SpatialSelf (Shared) — locate Self snapshots (and the source tree) for launch.
//
//  Mac: snapshots and the `.self` source both live in the developer's self64 tree, so
//  we read them in place. visionOS: the device sandbox can't see self64, so snapshots
//  are bundled into the app at build time (Phase 2) and there is no source tree to stat
//  at runtime. The platform factory `current` hides that difference.
//

import Foundation

struct SnapshotCatalog {
  /// Directory holding `*.snap` files to launch from.
  let snapshotsDir: URL
  /// Directory the running VM should write new snapshots into. On Mac this is `snapshotsDir`
  /// (self64), so a freshly saved snapshot is immediately the newest launch target; on
  /// visionOS the launch dir is the read-only bundle, so saves go to the writable sandbox.
  let saveDir:      URL
  /// Root of the `.self` source tree (objects/), or nil when unavailable (visionOS runtime).
  let sourceRoot:   URL?

  /// All snapshots, newest first.
  func entries() -> [Entry] {
    let keys: [URLResourceKey] = [.contentModificationDateKey]
    guard let urls = try? FileManager.default.contentsOfDirectory(at:                       snapshotsDir,
                                                                  includingPropertiesForKeys: keys,
                                                                  options:                    [.skipsHiddenFiles])
    else { return [] }
    return urls
      .filter   { $0.pathExtension == "snap" }
      .map      { Entry(url: $0, modified: $0.modificationDate) }
      .sorted   { $0.modified > $1.modified }
  }

  /// The newest snapshot — the default launch target (decision D1: auto-pick newest).
  func newest() -> Entry? { entries().first }
}

// MARK: - Entry
extension SnapshotCatalog {
  /// One launchable snapshot.
  struct Entry: Identifiable, Hashable {
    let url:      URL
    let modified: Date

    var id:   URL    { url }
    var name: String { url.lastPathComponent }
  }
}

// MARK: - Platform factory
extension SnapshotCatalog {
  /// The catalog for this host.
  static var current: SnapshotCatalog {
#if os(macOS)
    let self64 = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
      .appendingPathComponent("self/vms/OurSelf/self64", isDirectory: true)
    return SnapshotCatalog(snapshotsDir: self64,
                           saveDir:      self64,
                           sourceRoot:   self64.appendingPathComponent("objects", isDirectory: true))
#else
    // visionOS: snapshots bundled into the app (Phase 2); no `.self` tree on device.
    let dir = Bundle.main.resourceURL ?? Bundle.main.bundleURL
    return SnapshotCatalog(snapshotsDir: dir,
                           saveDir:      sandboxSnapshotsDir,
                           sourceRoot:   nil)
#endif
  }
}

// MARK: - Writable save location
extension SnapshotCatalog {
  /// `Application Support/Snapshots`, created on demand — where a sandboxed host (visionOS)
  /// writes snapshots it saves from the running VM.
  static var sandboxSnapshotsDir: URL {
    let base = (try? FileManager.default.url(for:                       .applicationSupportDirectory,
                                             in:                        .userDomainMask,
                                             appropriateFor:            nil,
                                             create:                    true))
             ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    let dir = base.appendingPathComponent("Snapshots", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
  }

  /// Absolute path the running VM should be told to save `baseName` to (`.snap` appended
  /// if missing), inside `saveDir`.
  func savePath(forBaseName baseName: String) -> String {
    let name = baseName.hasSuffix(".snap") ? baseName : baseName + ".snap"
    return saveDir.appendingPathComponent(name).path
  }
}

// MARK: - URL convenience
private extension URL {
  /// The file's modification date, or `.distantPast` if unreadable.
  var modificationDate: Date {
    (try? resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
  }
}

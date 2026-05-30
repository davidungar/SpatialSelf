//
//  SnapshotStaleness.swift
//  SpatialSelf (Shared) — cheap check: are any `.self` sources newer than the snapshot?
//
//  The user always wants to know when filed-in source has moved ahead of the snapshot
//  they're about to launch (so the snapshot is missing recent changes). On Mac this runs
//  at launch — one mtime per `.self` file, no contents read (~1150 stats, sub-10 ms). On
//  visionOS the source tree isn't on the device, so this returns `.unavailable` and the
//  check is done at build time instead (Phase 2).
//

import Foundation

enum SnapshotStaleness {
  /// Walk `sourceRoot` for `*.self` files and count those modified after `snapshot`.
  static func check(snapshot: URL, sourceRoot: URL?) -> Status {
    guard let sourceRoot,
          let snapDate = snapshot.modificationDate
    else { return .unavailable }

    guard let walker = FileManager.default.enumerator(at:                       sourceRoot,
                                                      includingPropertiesForKeys: [.contentModificationDateKey],
                                                      options:                    [.skipsHiddenFiles])
    else { return .unavailable }

    var count      = 0
    var newestName = ""
    var newestDate = snapDate
    for case let url as URL in walker where url.pathExtension == "self" {
      guard let date = url.modificationDate, date > snapDate else { continue }
      count += 1
      if date > newestDate {
        newestDate = date
        newestName = url.lastPathComponent
      }
    }
    return count == 0 ? .fresh : .stale(count: count, newest: newestName)
  }
}

// MARK: - Status
extension SnapshotStaleness {
  /// Outcome of comparing the snapshot's mtime against the `.self` source tree.
  enum Status: Equatable {
    case fresh                              // snapshot is at or ahead of all sources
    case stale(count: Int, newest: String) // `count` `.self` files are newer
    case unavailable                        // no source tree to compare (visionOS runtime)

    /// A short banner string, or nil when there's nothing to warn about.
    var warning: String? {
      switch self {
      case .fresh, .unavailable:        nil
      case .stale(let count, let name): "⚠︎ \(count) .self file\(count == 1 ? "" : "s") newer than this snapshot (newest: \(name))"
      }
    }
  }
}

// MARK: - URL convenience
private extension URL {
  var modificationDate: Date? {
    try? resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
  }
}

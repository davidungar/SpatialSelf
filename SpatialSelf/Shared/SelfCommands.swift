//
//  SelfCommands.swift
//  SpatialSelf (Shared) — Self expressions the host sends to the running VM over stdin.
//
//  Centralised so the exact wording is in one place. Each was verified live against the
//  VM (Debug build, ui2merge.snap) on 2026-05-30 — see the per-command notes. Self string
//  literals escape a single quote with a backslash, hence `escaped(_:)`.
//

import Foundation

enum SelfCommands {
  /// Save the running world to `absolutePath`.
  ///
  /// Verified: neither `modules` nor `shell shortcuts` can reach `memory` from their own
  /// context (so `shell shortcuts saveAs:` fails), but the prompt's lobby can — so we drive
  /// `memory` directly, which is exactly what `saveAs:` does internally. Writes the file and
  /// the running VM continues.
  static func saveSnapshot(toPath absolutePath: String) -> String {
    let p = escaped(absolutePath)
    return "[memory snapshotOptions: memory snapshotOptions copy. "
         + "memory snapshotOptions fileName: '\(p)'. "
         + "memory writeSnapshotIfBackupFails: [|:e| ('snapshot backup failed: ', e printString) printLine] "
         + "IfSnapshotFails: [|:e| ('snapshot save failed: ', e printString) printLine]] value"
  }

  /// File out a single module by name. Verified path (module.self): a module's `fileOut`
  /// is `transporter fileOut fileOutModule: name`, so we call that directly.
  static func fileOutModule(_ name: String) -> String {
    "transporter fileOut fileOutModule: '\(escaped(name))'"
  }

  /// File out only the changed (dirty) modules (decision D3). Uses the canonical dirty
  /// tracking on `transporter moduleDictionary` (verified: `updateDirtyModules` recomputes
  /// the set, `dirtyModules` returns the module objects, each of which answers `fileOut`).
  /// The bare `modules` namespace does not expose this, so we go through the dictionary.
  static let fileOutChangedModules =
    "[transporter moduleDictionary updateDirtyModules. "
    + "transporter moduleDictionary dirtyModules do: [|:m| m fileOut]] value"

  // MARK: - Helpers

  /// Escape a string for inclusion in a Self single-quoted literal.
  private static func escaped(_ s: String) -> String {
    s.replacingOccurrences(of: "\\", with: "\\\\")
     .replacingOccurrences(of: "'",  with: "\\'")
  }
}

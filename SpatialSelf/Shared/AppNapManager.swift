//
//  AppNapManager.swift
//  SpatialSelf (macOS only) — smooth VM animation on AC, frugal on battery.
//
//  App Nap throttles a non-frontmost app's timers, coalescing the VM's 10 ms ticker into
//  50–100 ms SELFTIMER stalls — so timer-driven (ui2) animation stutters while the window
//  is unfocused. We suppress App Nap, but only while on AC power: there the extra ~watt of a
//  full-rate background ticker is free, whereas on battery we WANT it throttled so an unfocused
//  window doesn't drain the pack. We use `.userInitiatedAllowingIdleSystemSleep` (not plain
//  `.userInitiated`) so App Nap is suppressed WITHOUT blocking the Mac's normal idle sleep —
//  we have no reason to keep the machine awake.
//
//  Gated on power source, NOT scene phase: App Nap only throttles when the app is already
//  unfocused, so the assertion must be held while backgrounded — gating it to "active" would
//  defeat it. visionOS has no App Nap, so this whole file is macOS-only.
//

#if os(macOS)

import Foundation
import IOKit.ps

final class AppNapManager {
  static let shared = AppNapManager()

  private var activity:      NSObjectProtocol?
  private var runLoopSource: CFRunLoopSource?

  /// Begin watching the power source and keep the App Nap assertion in sync. Idempotent;
  /// call once at app launch (on the main thread).
  func start() {
    guard runLoopSource == nil else { return }
    let context = Unmanaged.passUnretained(self).toOpaque()
    guard let source = IOPSNotificationCreateRunLoopSource({ ctx in
      guard let ctx else { return }
      Unmanaged<AppNapManager>.fromOpaque(ctx).takeUnretainedValue().sync()
    }, context)?.takeRetainedValue()
    else { return }
    runLoopSource = source
    CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
    sync()
  }

  /// Hold the assertion iff on AC; the run-loop source calls this on every power change.
  private func sync() {
    if Self.isOnACPower() { suppressAppNap() }
    else                  { allowAppNap()    }
  }

  private func suppressAppNap() {
    guard activity == nil else { return }
    activity = ProcessInfo.processInfo.beginActivity(
      options: .userInitiatedAllowingIdleSystemSleep,
      reason:  "Keep Self VM timer-driven animation smooth while unfocused (AC power)")
  }

  private func allowAppNap() {
    guard let activity else { return }
    ProcessInfo.processInfo.endActivity(activity)
    self.activity = nil
  }

  /// True on AC (or when the source is unknown — desktops have no battery, so prefer smooth).
  private static func isOnACPower() -> Bool {
    guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
          let type = IOPSGetProvidingPowerSourceType(blob)?.takeUnretainedValue() as String?
    else { return true }
    return type == kIOPSACPowerValue
  }
}

#endif

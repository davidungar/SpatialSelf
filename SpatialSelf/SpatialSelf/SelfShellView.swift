//
//  SelfShellView.swift
//  SpatialSelf
//
//  Simple shell window: a TerminalView that talks to the running
//  Self VM. Add buttons here as the AVP workflow evolves (snapshot
//  read/write, etc.).
//

import SwiftUI
import Views

struct SelfShellView: View {
  var body: some View {
    VStack(spacing: 0) {
      TerminalView()
    }
  }
}

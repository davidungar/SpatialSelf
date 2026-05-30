//
//  OutputStream.swift
//  SpatialSelf — copied verbatim from Self_1 so Terminal_IO_Redirector
//  can compile here. Long-term home is shared, not duplicated.
//

import SwiftUI
import Views

enum OutputStream: TerminalOutputStreamProtocol {
  static let realStdout = stdout
  static let redirectedStdout = selfStdout
  static let redirectedStderr = selfStderr
  
  case
  selfStdout,
  selfStderr,
  vmStdout,
  vmStderr,
  printPrimitive,
  stringPrintPrimitive,
  stdout
}

extension OutputStream {
  var color: Color {
    return switch self {
    case .selfStdout:           .primary
    case .selfStderr:           .pink
    case .vmStdout:             .teal
    case .vmStderr:             .orange
    case .printPrimitive:       .blue
    case .stringPrintPrimitive: .cyan
    case .stdout:               .primary
    }
  }
}

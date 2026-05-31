import Foundation

public enum WAMsgError: Error, CustomStringConvertible, Equatable {
  case permissionDenied(path: String, reason: String)
  case invalidDatabase(path: String, reason: String)
  case invalidISODate(String)
  case invalidSendTarget
  case invalidMessage
  case appleScriptFailure(String)

  public var description: String {
    switch self {
    case .permissionDenied(let path, let reason):
      return
        "Unable to open WhatsApp database at \(path). Grant Full Disk Access to your terminal. \(reason)"
    case .invalidDatabase(let path, let reason):
      return "Invalid WhatsApp database at \(path): \(reason)"
    case .invalidISODate(let value):
      return "Invalid ISO8601 date: \(value)"
    case .invalidSendTarget:
      return "Missing WhatsApp contact or chat name"
    case .invalidMessage:
      return "Missing WhatsApp message text"
    case .appleScriptFailure(let message):
      return "AppleScript failed: \(message)"
    }
  }
}


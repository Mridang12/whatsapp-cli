import Foundation

public enum WAMsgError: Error, CustomStringConvertible, Equatable {
  case permissionDenied(path: String, reason: String)
  case invalidDatabase(path: String, reason: String)
  case invalidISODate(String)
  case invalidSendTarget
  case invalidMessage
  case noExactChatMatch(String)
  case ambiguousChatMatch(String, Int)
  case strictSendRequiresPhoneNumber(String)
  case appleScriptFailure(String)
  case messageNotFound(rowID: Int64, chatID: Int64)

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
    case .noExactChatMatch(let target):
      return
        "No exact WhatsApp chat match for '\(target)'. Use the exact name from 'wmsg chats', a phone number, or pass --allow-loose-match."
    case .ambiguousChatMatch(let target, let count):
      return
        "Ambiguous WhatsApp chat target '\(target)': \(count) exact matches. Use a phone number or a more specific chat name."
    case .strictSendRequiresPhoneNumber(let target):
      return
        "Strict WhatsApp sends require a phone-number-backed direct chat for '\(target)'. Group chats and identifier-only chats require --allow-loose-match."
    case .appleScriptFailure(let message):
      return "AppleScript failed: \(message)"
    case .messageNotFound(let rowID, let chatID):
      return "No WhatsApp message with rowID \(rowID) in chat \(chatID)"
    }
  }
}

import Foundation

public struct WhatsAppMessageFilter: Sendable, Equatable {
  public let participants: [String]
  public let startDate: Date?
  public let endDate: Date?

  public init(participants: [String] = [], startDate: Date? = nil, endDate: Date? = nil) {
    self.participants = participants
    self.startDate = startDate
    self.endDate = endDate
  }

  public static func fromISO(participants: [String], startISO: String?, endISO: String?) throws
    -> WhatsAppMessageFilter
  {
    let start = startISO.flatMap { WhatsAppISO8601.parse($0) }
    if let startISO, start == nil {
      throw WAMsgError.invalidISODate(startISO)
    }
    let end = endISO.flatMap { WhatsAppISO8601.parse($0) }
    if let endISO, end == nil {
      throw WAMsgError.invalidISODate(endISO)
    }
    return WhatsAppMessageFilter(participants: participants, startDate: start, endDate: end)
  }

  public func allows(_ message: WhatsAppMessage) -> Bool {
    if let startDate, message.date < startDate { return false }
    if let endDate, message.date >= endDate { return false }
    if participants.isEmpty { return true }
    return participants.contains { $0.caseInsensitiveCompare(message.sender) == .orderedSame }
  }
}

enum WhatsAppISO8601 {
  static func parse(_ value: String) -> Date? {
    if value.isEmpty { return nil }
    let fractional = ISO8601DateFormatter()
    fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = fractional.date(from: value) {
      return date
    }
    let standard = ISO8601DateFormatter()
    standard.formatOptions = [.withInternetDateTime]
    return standard.date(from: value)
  }
}


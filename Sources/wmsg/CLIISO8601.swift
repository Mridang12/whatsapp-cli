import Foundation

enum CLIISO8601 {
  static func format(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.string(from: date)
  }

  /// ISO8601 timestamp in the given time zone with an explicit UTC offset, e.g. `2026-09-20T17:51:43.000-07:00`.
  static func formatLocal(_ date: Date, timeZone: TimeZone = .current) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    formatter.timeZone = timeZone
    return formatter.string(from: date)
  }
}

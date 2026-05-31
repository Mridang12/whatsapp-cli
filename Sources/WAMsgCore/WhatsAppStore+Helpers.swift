import Foundation
import SQLite

extension WhatsAppStore {
  static func tableNames(connection: Connection) -> Set<String> {
    do {
      let rows = try connection.prepareRowIterator(
        "SELECT name FROM sqlite_master WHERE type = 'table'"
      )
      var names = Set<String>()
      while let row = try rows.failableNext() {
        if let name = try row.get(Expression<String?>("name")) {
          names.insert(name.lowercased())
        }
      }
      return names
    } catch {
      return []
    }
  }

  static func tableColumns(connection: Connection, table: String) -> Set<String> {
    do {
      let rows = try connection.prepareRowIterator("PRAGMA table_info(\(table))")
      var columns = Set<String>()
      while let row = try rows.failableNext() {
        if let name = try row.get(Expression<String?>("name")) {
          columns.insert(name.lowercased())
        }
      }
      return columns
    } catch {
      return []
    }
  }

  static func enhance(error: Error, path: String) -> Error {
    let message = String(describing: error)
    let lower = message.lowercased()
    if lower.contains("authorization denied") || lower.contains("unable to open database")
      || lower.contains("cannot open") || lower.contains("out of memory (14)")
    {
      return WAMsgError.permissionDenied(path: path, reason: message)
    }
    return error
  }

  public static func whatsappEpoch(_ date: Date) -> Double {
    date.timeIntervalSince1970 - appleEpochOffset
  }

  func whatsappDate(from value: Double?) -> Date {
    guard let value else { return Date(timeIntervalSince1970: Self.appleEpochOffset) }
    return Date(timeIntervalSince1970: value + Self.appleEpochOffset)
  }

  func stringValue(_ row: Row, _ column: String) throws -> String {
    if let value = try? row.get(Expression<String?>(column)) {
      return value
    }
    if let value = try? row.get(Expression<Int64?>(column)) {
      return String(value)
    }
    if let value = try? row.get(Expression<Double?>(column)) {
      return String(value)
    }
    return ""
  }

  func int64Value(_ row: Row, _ column: String) throws -> Int64? {
    if let value = try? row.get(Expression<Int64?>(column)) {
      return value
    }
    if let value = try? row.get(Expression<Double?>(column)) {
      return Int64(value)
    }
    if let value = try? row.get(Expression<String?>(column)) {
      return Int64(value)
    }
    return nil
  }

  func intValue(_ row: Row, _ column: String) throws -> Int? {
    guard let value = try int64Value(row, column) else { return nil }
    return Int(value)
  }

  func doubleValue(_ row: Row, _ column: String) throws -> Double? {
    if let value = try? row.get(Expression<Double?>(column)) {
      return value
    }
    if let value = try? row.get(Expression<Int64?>(column)) {
      return Double(value)
    }
    if let value = try? row.get(Expression<String?>(column)) {
      return Double(value)
    }
    return nil
  }

  func boolValue(_ row: Row, _ column: String) throws -> Bool {
    if let value = try? row.get(Expression<Bool?>(column)) {
      return value
    }
    return (try intValue(row, column) ?? 0) != 0
  }
}

extension String {
  var nilIfEmpty: String? {
    isEmpty ? nil : self
  }
}

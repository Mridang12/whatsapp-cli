import Foundation
import SQLite

extension WhatsAppStore {
  public func listChats(limit: Int = 20, includeSystemChats: Bool = false) throws
    -> [WhatsAppChat]
  {
    let pushNameJoin = pushNameJoin()
    let pushNameColumn = schema.hasPushNameTable ? "NULLIF(pn.ZPUSHNAME, '')" : "NULL"
    let systemFilter = includeSystemChats ? "" : "AND NOT \(systemChatPredicate("c.ZCONTACTJID"))"
    let sql = """
      SELECT c.Z_PK AS chat_id,
             IFNULL(c.ZCONTACTJID, '') AS identifier,
             COALESCE(NULLIF(c.ZPARTNERNAME, ''), \(pushNameColumn), NULLIF(c.ZCONTACTJID, ''), '') AS name,
             \(lastMessageTextExpression()) AS last_message_text,
             c.ZLASTMESSAGEDATE AS last_message_date,
             IFNULL(c.ZUNREADCOUNT, 0) AS unread_count,
             IFNULL(c.ZARCHIVED, 0) AS archived,
             IFNULL(c.ZREMOVED, 0) AS removed,
             c.ZSESSIONTYPE AS session_type,
             CASE WHEN IFNULL(c.ZCONTACTJID, '') LIKE '%@g.us' THEN 1 ELSE 0 END AS is_group
      FROM ZWACHATSESSION c
      \(pushNameJoin)
      \(lastMessageJoin())
      WHERE IFNULL(c.ZREMOVED, 0) = 0
        \(systemFilter)
      ORDER BY c.ZLASTMESSAGEDATE DESC, c.Z_PK DESC
      LIMIT ?
      """
    return try withConnection { db in
      var chats: [WhatsAppChat] = []
      let rows = try db.prepareRowIterator(sql, bindings: [max(0, limit)])
      while let row = try rows.failableNext() {
        chats.append(try decodeChat(row))
      }
      return chats
    }
  }

  public func chatInfo(chatID: Int64) throws -> WhatsAppChat? {
    let pushNameJoin = pushNameJoin()
    let pushNameColumn = schema.hasPushNameTable ? "NULLIF(pn.ZPUSHNAME, '')" : "NULL"
    let sql = """
      SELECT c.Z_PK AS chat_id,
             IFNULL(c.ZCONTACTJID, '') AS identifier,
             COALESCE(NULLIF(c.ZPARTNERNAME, ''), \(pushNameColumn), NULLIF(c.ZCONTACTJID, ''), '') AS name,
             \(lastMessageTextExpression()) AS last_message_text,
             c.ZLASTMESSAGEDATE AS last_message_date,
             IFNULL(c.ZUNREADCOUNT, 0) AS unread_count,
             IFNULL(c.ZARCHIVED, 0) AS archived,
             IFNULL(c.ZREMOVED, 0) AS removed,
             c.ZSESSIONTYPE AS session_type,
             CASE WHEN IFNULL(c.ZCONTACTJID, '') LIKE '%@g.us' THEN 1 ELSE 0 END AS is_group
      FROM ZWACHATSESSION c
      \(pushNameJoin)
      \(lastMessageJoin())
      WHERE c.Z_PK = ?
      LIMIT 1
      """
    return try withConnection { db in
      let rows = try db.prepareRowIterator(sql, bindings: [chatID])
      guard let row = try rows.failableNext() else { return nil }
      return try decodeChat(row)
    }
  }

  public func chatInfo(identifier: String) throws -> WhatsAppChat? {
    let sql = """
      SELECT Z_PK AS chat_id
      FROM ZWACHATSESSION
      WHERE ZCONTACTJID = ? OR ZPARTNERNAME = ?
      ORDER BY ZLASTMESSAGEDATE DESC, Z_PK DESC
      LIMIT 1
      """
    let chatID: Int64? = try withConnection { db in
      let rows = try db.prepareRowIterator(sql, bindings: [identifier, identifier])
      guard let row = try rows.failableNext() else { return nil }
      return try int64Value(row, "chat_id")
    }
    guard let chatID else { return nil }
    return try chatInfo(chatID: chatID)
  }

  public func exactChats(matching target: String, includeSystemChats: Bool = false) throws
    -> [WhatsAppChat]
  {
    let trimmed = target.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return [] }
    let normalized = trimmed.lowercased()
    let phoneDigits = Self.phoneDigits(from: trimmed)
    let pushNameJoin = pushNameJoin()
    let pushNameColumn = schema.hasPushNameTable ? "NULLIF(pn.ZPUSHNAME, '')" : "NULL"
    let systemFilter = includeSystemChats ? "" : "AND NOT \(systemChatPredicate("c.ZCONTACTJID"))"
    let sql = """
      SELECT c.Z_PK AS chat_id,
             IFNULL(c.ZCONTACTJID, '') AS identifier,
             COALESCE(NULLIF(c.ZPARTNERNAME, ''), \(pushNameColumn), NULLIF(c.ZCONTACTJID, ''), '') AS name,
             \(lastMessageTextExpression()) AS last_message_text,
             c.ZLASTMESSAGEDATE AS last_message_date,
             IFNULL(c.ZUNREADCOUNT, 0) AS unread_count,
             IFNULL(c.ZARCHIVED, 0) AS archived,
             IFNULL(c.ZREMOVED, 0) AS removed,
             c.ZSESSIONTYPE AS session_type,
             CASE WHEN IFNULL(c.ZCONTACTJID, '') LIKE '%@g.us' THEN 1 ELSE 0 END AS is_group
      FROM ZWACHATSESSION c
      \(pushNameJoin)
      \(lastMessageJoin())
      WHERE IFNULL(c.ZREMOVED, 0) = 0
        \(systemFilter)
        AND (
          lower(trim(IFNULL(c.ZPARTNERNAME, ''))) = ?
          OR lower(trim(IFNULL(c.ZCONTACTJID, ''))) = ?
          OR lower(trim(COALESCE(\(pushNameColumn), ''))) = ?
          OR replace(replace(replace(replace(replace(replace(lower(IFNULL(c.ZCONTACTJID, '')), '@s.whatsapp.net', ''), '+', ''), ' ', ''), '-', ''), '(', ''), ')', '') = ?
        )
      GROUP BY c.Z_PK
      ORDER BY c.ZLASTMESSAGEDATE DESC, c.Z_PK DESC
      """
    return try withConnection { db in
      var chats: [WhatsAppChat] = []
      let rows = try db.prepareRowIterator(
        sql,
        bindings: [normalized, normalized, normalized, phoneDigits]
      )
      while let row = try rows.failableNext() {
        chats.append(try decodeChat(row))
      }
      return chats
    }
  }

  public func participants(chatID: Int64) throws -> [String] {
    guard schema.hasGroupMemberTable else {
      return try chatInfo(chatID: chatID).map { [$0.identifier] } ?? []
    }
    let sql = """
      SELECT IFNULL(ZMEMBERJID, '') AS member_jid
      FROM ZWAGROUPMEMBER
      WHERE ZCHATSESSION = ? AND IFNULL(ZISACTIVE, 1) != 0
      ORDER BY ZCONTACTNAME COLLATE NOCASE ASC, ZMEMBERJID COLLATE NOCASE ASC
      """
    let participants: [String] = try withConnection { db in
      var participants: [String] = []
      var seen = Set<String>()
      let rows = try db.prepareRowIterator(sql, bindings: [chatID])
      while let row = try rows.failableNext() {
        let member = try stringValue(row, "member_jid")
        guard !member.isEmpty, seen.insert(member).inserted else { continue }
        participants.append(member)
      }
      return participants
    }
    if participants.isEmpty, let chat = try chatInfo(chatID: chatID), !chat.identifier.isEmpty {
      return [chat.identifier]
    }
    return participants
  }

  private func decodeChat(_ row: Row) throws -> WhatsAppChat {
    let identifier = try stringValue(row, "identifier")
    let name = try stringValue(row, "name")
    return WhatsAppChat(
      id: try int64Value(row, "chat_id") ?? 0,
      identifier: identifier,
      name: name.isEmpty ? identifier : name,
      lastMessageAt: whatsappDate(from: try doubleValue(row, "last_message_date")),
      lastMessageText: try stringValue(row, "last_message_text"),
      unreadCount: try intValue(row, "unread_count") ?? 0,
      isArchived: try boolValue(row, "archived"),
      isRemoved: try boolValue(row, "removed"),
      isGroup: try boolValue(row, "is_group"),
      sessionType: try intValue(row, "session_type")
    )
  }

  private func pushNameJoin() -> String {
    guard schema.hasPushNameTable else { return "" }
    return """
      LEFT JOIN (
        SELECT ZJID, MIN(NULLIF(ZPUSHNAME, '')) AS ZPUSHNAME
        FROM ZWAPROFILEPUSHNAME
        GROUP BY ZJID
      ) pn ON pn.ZJID = c.ZCONTACTJID
      """
  }

  /// Newer WhatsApp builds store an encoded blob in `ZLASTMESSAGETEXT`, so prefer the text of
  /// the chat's last message row when the schema links it.
  private func lastMessageJoin() -> String {
    guard schema.chatColumns.contains("zlastmessage") else { return "" }
    return "LEFT JOIN ZWAMESSAGE lm ON lm.Z_PK = c.ZLASTMESSAGE"
  }

  private func lastMessageTextExpression() -> String {
    guard schema.chatColumns.contains("zlastmessage") else {
      return "IFNULL(c.ZLASTMESSAGETEXT, '')"
    }
    return "CASE WHEN lm.Z_PK IS NOT NULL THEN IFNULL(lm.ZTEXT, '') ELSE IFNULL(c.ZLASTMESSAGETEXT, '') END"
  }

  private func systemChatPredicate(_ jidExpression: String) -> String {
    """
    (
      lower(IFNULL(\(jidExpression), '')) LIKE '%@status'
      OR lower(IFNULL(\(jidExpression), '')) LIKE '%.status'
      OR lower(IFNULL(\(jidExpression), '')) = 'status@broadcast'
      OR lower(IFNULL(\(jidExpression), '')) LIKE '%@broadcast'
    )
    """
  }

  public static func phoneDigits(from value: String) -> String {
    value.filter { $0.isNumber }
  }

  /// Returns the phone number digits for a phone-backed identifier. WhatsApp `@lid`, group, and
  /// broadcast identifiers are opaque ids, not phone numbers, so they return `nil`.
  public static func phoneNumber(fromIdentifier value: String) -> String? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if let at = trimmed.firstIndex(of: "@"), trimmed[at...] != "@s.whatsapp.net" {
      return nil
    }
    let digits = phoneDigits(from: trimmed)
    return digits.isEmpty ? nil : digits
  }
}

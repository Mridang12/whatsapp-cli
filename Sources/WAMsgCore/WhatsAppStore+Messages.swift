import Foundation
import SQLite

extension WhatsAppStore {
  public func maxRowID() throws -> Int64 {
    try withConnection { db in
      let value = try db.scalar("SELECT MAX(Z_PK) FROM ZWAMESSAGE")
      return int64Value(value) ?? 0
    }
  }

  public func messages(chatID: Int64, limit: Int = 50) throws -> [WhatsAppMessage] {
    try messages(chatID: chatID, limit: limit, filter: nil)
  }

  public func messages(chatID: Int64, limit: Int, filter: WhatsAppMessageFilter?) throws
    -> [WhatsAppMessage]
  {
    var sql = """
      SELECT \(messageSelectList())
      FROM ZWAMESSAGE m
      JOIN ZWACHATSESSION c ON c.Z_PK = m.ZCHATSESSION
      \(messageGroupMemberJoin())
      \(messagePushNameJoin())
      WHERE m.ZCHATSESSION = ?
      """
    var bindings: [Binding?] = [chatID]
    appendFilter(filter, to: &sql, bindings: &bindings)
    sql += " ORDER BY m.ZMESSAGEDATE DESC, m.Z_PK DESC LIMIT ?"
    bindings.append(max(0, limit))

    return try withConnection { db in
      var messages: [WhatsAppMessage] = []
      let rows = try db.prepareRowIterator(sql, bindings: bindings)
      while let row = try rows.failableNext() {
        messages.append(try decodeMessage(row))
      }
      return messages
    }
  }

  public func messagesAfter(afterRowID: Int64, chatID: Int64?, limit: Int = 100) throws
    -> [WhatsAppMessage]
  {
    var sql = """
      SELECT \(messageSelectList())
      FROM ZWAMESSAGE m
      JOIN ZWACHATSESSION c ON c.Z_PK = m.ZCHATSESSION
      \(messageGroupMemberJoin())
      \(messagePushNameJoin())
      WHERE m.Z_PK > ?
      """
    var bindings: [Binding?] = [afterRowID]
    if let chatID {
      sql += " AND m.ZCHATSESSION = ?"
      bindings.append(chatID)
    }
    sql += " ORDER BY m.Z_PK ASC LIMIT ?"
    bindings.append(max(0, limit))

    return try withConnection { db in
      var messages: [WhatsAppMessage] = []
      let rows = try db.prepareRowIterator(sql, bindings: bindings)
      while let row = try rows.failableNext() {
        messages.append(try decodeMessage(row))
      }
      return messages
    }
  }

  public func latestSentMessage(text: String, chatID: Int64?, since date: Date) throws
    -> WhatsAppMessage?
  {
    var sql = """
      SELECT \(messageSelectList())
      FROM ZWAMESSAGE m
      JOIN ZWACHATSESSION c ON c.Z_PK = m.ZCHATSESSION
      \(messageGroupMemberJoin())
      \(messagePushNameJoin())
      WHERE IFNULL(m.ZISFROMME, 0) = 1
        AND IFNULL(m.ZTEXT, '') = ?
        AND m.ZMESSAGEDATE >= ?
      """
    var bindings: [Binding?] = [text, Self.whatsappEpoch(date)]
    if let chatID {
      sql += " AND m.ZCHATSESSION = ?"
      bindings.append(chatID)
    }
    sql += " ORDER BY m.ZMESSAGEDATE DESC, m.Z_PK DESC LIMIT 1"

    return try withConnection { db in
      let rows = try db.prepareRowIterator(sql, bindings: bindings)
      guard let row = try rows.failableNext() else { return nil }
      return try decodeMessage(row)
    }
  }

  private func appendFilter(
    _ filter: WhatsAppMessageFilter?,
    to sql: inout String,
    bindings: inout [Binding?]
  ) {
    guard let filter else { return }
    if let startDate = filter.startDate {
      sql += " AND m.ZMESSAGEDATE >= ?"
      bindings.append(Self.whatsappEpoch(startDate))
    }
    if let endDate = filter.endDate {
      sql += " AND m.ZMESSAGEDATE < ?"
      bindings.append(Self.whatsappEpoch(endDate))
    }
    if !filter.participants.isEmpty {
      let placeholders = Array(repeating: "?", count: filter.participants.count).joined(
        separator: ","
      )
      sql += " AND \(senderExpression()) COLLATE NOCASE IN (\(placeholders))"
      bindings.append(contentsOf: filter.participants)
    }
  }

  private func messageSelectList() -> String {
    let attachmentsCount =
      schema.hasMediaItemTable
      ? """
        (SELECT COUNT(*)
         FROM ZWAMEDIAITEM mi
         WHERE mi.ZMESSAGE = m.Z_PK OR (m.ZMEDIAITEM IS NOT NULL AND mi.Z_PK = m.ZMEDIAITEM))
        """
      : "0"
    return """
      m.Z_PK AS message_id,
      m.ZCHATSESSION AS chat_id,
      \(senderExpression()) AS sender,
      \(senderNameExpression()) AS sender_name,
      IFNULL(m.ZTEXT, '') AS text,
      m.ZMESSAGEDATE AS message_date,
      IFNULL(m.ZISFROMME, 0) AS is_from_me,
      IFNULL(m.ZSTANZAID, '') AS stanza_id,
      IFNULL(m.ZFROMJID, '') AS from_jid,
      IFNULL(m.ZTOJID, '') AS to_jid,
      m.ZMESSAGETYPE AS message_type,
      m.ZMESSAGESTATUS AS message_status,
      m.ZMESSAGEERRORSTATUS AS error_status,
      \(attachmentsCount) AS attachments_count
      """
  }

  private func messageGroupMemberJoin() -> String {
    schema.hasGroupMemberTable ? "LEFT JOIN ZWAGROUPMEMBER gm ON gm.Z_PK = m.ZGROUPMEMBER" : ""
  }

  private func messagePushNameJoin() -> String {
    guard schema.hasPushNameTable else { return "" }
    return "LEFT JOIN ZWAPROFILEPUSHNAME pn ON pn.ZJID = \(senderJIDExpression())"
  }

  private func groupMemberJIDColumn() -> String {
    schema.hasGroupMemberTable ? "NULLIF(gm.ZMEMBERJID, '')" : "NULL"
  }

  private func groupMemberNameColumn() -> String {
    guard schema.hasGroupMemberTable else { return "NULL" }
    return "NULLIF(COALESCE(NULLIF(gm.ZCONTACTNAME, ''), NULLIF(gm.ZFIRSTNAME, '')), '')"
  }

  private func pushNameColumn() -> String {
    schema.hasPushNameTable ? "NULLIF(pn.ZPUSHNAME, '')" : "NULL"
  }

  private func senderJIDExpression() -> String {
    """
    COALESCE(NULLIF(m.ZFROMJID, ''), \(groupMemberJIDColumn()), CASE WHEN IFNULL(m.ZISFROMME, 0) = 1 THEN NULL ELSE NULLIF(c.ZCONTACTJID, '') END)
    """
  }

  private func senderExpression() -> String {
    """
    COALESCE(NULLIF(m.ZFROMJID, ''), \(groupMemberJIDColumn()), CASE WHEN IFNULL(m.ZISFROMME, 0) = 1 THEN 'me' ELSE NULLIF(c.ZCONTACTJID, '') END, '')
    """
  }

  private func senderNameExpression() -> String {
    """
    CASE
      WHEN IFNULL(m.ZISFROMME, 0) = 1 THEN 'me'
      ELSE COALESCE(NULLIF(m.ZPUSHNAME, ''), \(groupMemberNameColumn()), \(pushNameColumn()), '')
    END
    """
  }

  private func decodeMessage(_ row: Row) throws -> WhatsAppMessage {
    return WhatsAppMessage(
      rowID: try int64Value(row, "message_id") ?? 0,
      chatID: try int64Value(row, "chat_id") ?? 0,
      sender: try stringValue(row, "sender"),
      senderName: try stringValue(row, "sender_name").nilIfEmpty,
      text: try stringValue(row, "text"),
      date: whatsappDate(from: try doubleValue(row, "message_date")),
      isFromMe: try boolValue(row, "is_from_me"),
      stanzaID: try stringValue(row, "stanza_id"),
      fromJID: try stringValue(row, "from_jid").nilIfEmpty,
      toJID: try stringValue(row, "to_jid").nilIfEmpty,
      messageType: try intValue(row, "message_type"),
      messageStatus: try intValue(row, "message_status"),
      errorStatus: try intValue(row, "error_status"),
      attachmentsCount: try intValue(row, "attachments_count") ?? 0
    )
  }

  private func int64Value(_ binding: Binding?) -> Int64? {
    if let value = binding as? Int64 { return value }
    if let value = binding as? Int { return Int64(value) }
    if let value = binding as? Double { return Int64(value) }
    return nil
  }
}


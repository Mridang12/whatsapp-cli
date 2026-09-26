import Foundation
import SQLite

public enum WhatsAppMessageOrder: String, Sendable, Equatable {
  /// Select the newest messages that match and return them newest first.
  case newestFirst = "newest"
  /// Select the oldest messages that match and return them oldest first.
  case oldestFirst = "oldest"
}

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

  /// Returns messages for a chat in WhatsApp's own conversation order (`ZSORT`), which is what
  /// the WhatsApp UI shows. Message row ids (`Z_PK`) are insertion order and are not chronological.
  ///
  /// - Parameters:
  ///   - order: `.newestFirst` selects the newest `limit` matches; `.oldestFirst` selects the oldest.
  ///   - beforeRowID: Only include messages that come before this message in the conversation.
  ///   - afterRowID: Only include messages that come after this message in the conversation.
  public func messages(
    chatID: Int64,
    limit: Int,
    filter: WhatsAppMessageFilter?,
    order: WhatsAppMessageOrder = .newestFirst,
    beforeRowID: Int64? = nil,
    afterRowID: Int64? = nil
  ) throws -> [WhatsAppMessage] {
    var sql = """
      SELECT \(messageSelectList())
      FROM ZWAMESSAGE m
      JOIN ZWACHATSESSION c ON c.Z_PK = m.ZCHATSESSION
      \(messageJoins())
      WHERE m.ZCHATSESSION = ?
      """
    var bindings: [Binding?] = [chatID]
    appendFilter(filter, to: &sql, bindings: &bindings)
    if let beforeRowID {
      let key = try orderKey(rowID: beforeRowID, chatID: chatID)
      sql += " AND (\(orderKeyColumns())) < (?, ?, ?)"
      bindings.append(contentsOf: key)
    }
    if let afterRowID {
      let key = try orderKey(rowID: afterRowID, chatID: chatID)
      sql += " AND (\(orderKeyColumns())) > (?, ?, ?)"
      bindings.append(contentsOf: key)
    }
    sql += " ORDER BY \(orderByClause(descending: order == .newestFirst)) LIMIT ?"
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
      \(messageJoins())
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
      \(messageJoins())
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

  private var hasSortColumn: Bool { schema.messageColumns.contains("zsort") }

  private func orderKeyColumns() -> String {
    let sort = hasSortColumn ? "IFNULL(m.ZSORT, 0)" : "0"
    return "\(sort), IFNULL(m.ZMESSAGEDATE, 0), m.Z_PK"
  }

  private func orderByClause(descending: Bool) -> String {
    let direction = descending ? "DESC" : "ASC"
    var terms: [String] = []
    if hasSortColumn {
      terms.append("IFNULL(m.ZSORT, 0) \(direction)")
    }
    terms.append("IFNULL(m.ZMESSAGEDATE, 0) \(direction)")
    terms.append("m.Z_PK \(direction)")
    return terms.joined(separator: ", ")
  }

  private func orderKey(rowID: Int64, chatID: Int64) throws -> [Binding?] {
    let sort = hasSortColumn ? "IFNULL(m.ZSORT, 0)" : "0"
    let sql = """
      SELECT \(sort) AS sort_key, IFNULL(m.ZMESSAGEDATE, 0) AS date_key, m.Z_PK AS row_key
      FROM ZWAMESSAGE m
      WHERE m.Z_PK = ? AND m.ZCHATSESSION = ?
      """
    let key: [Binding?]? = try withConnection { db in
      let rows = try db.prepareRowIterator(sql, bindings: [rowID, chatID])
      guard let row = try rows.failableNext() else { return nil }
      return [
        try int64Value(row, "sort_key") ?? 0,
        try doubleValue(row, "date_key") ?? 0,
        try int64Value(row, "row_key") ?? rowID,
      ]
    }
    guard let key else {
      throw WAMsgError.messageNotFound(rowID: rowID, chatID: chatID)
    }
    return key
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
      \(attachmentsCountExpression()) AS attachments_count
      """
  }

  private func attachmentsCountExpression() -> String {
    guard schema.hasMediaItemTable else { return "0" }
    return """
      (SELECT COUNT(*)
       FROM ZWAMEDIAITEM mi
       WHERE (mi.ZMESSAGE = m.Z_PK OR (m.ZMEDIAITEM IS NOT NULL AND mi.Z_PK = m.ZMEDIAITEM))
         AND \(mediaItemHasContentPredicate(alias: "mi")))
      """
  }

  private func messageJoins() -> String {
    var joins: [String] = []
    if schema.hasGroupMemberTable {
      joins.append("LEFT JOIN ZWAGROUPMEMBER gm ON gm.Z_PK = m.ZGROUPMEMBER")
    }
    if schema.hasPushNameTable {
      joins.append(
        """
        LEFT JOIN (
          SELECT ZJID, MIN(NULLIF(ZPUSHNAME, '')) AS ZPUSHNAME
          FROM ZWAPROFILEPUSHNAME
          GROUP BY ZJID
        ) pn ON pn.ZJID = \(senderJIDExpression())
        """
      )
    }
    joins.append(
      """
      LEFT JOIN (
        SELECT ZCONTACTJID, MIN(NULLIF(ZPARTNERNAME, '')) AS ZPARTNERNAME
        FROM ZWACHATSESSION
        WHERE IFNULL(ZCONTACTJID, '') NOT LIKE '%@g.us'
        GROUP BY ZCONTACTJID
      ) sc ON sc.ZCONTACTJID = \(senderJIDExpression())
      """
    )
    return joins.joined(separator: "\n")
  }

  private func groupMemberJIDColumn() -> String {
    schema.hasGroupMemberTable ? "NULLIF(gm.ZMEMBERJID, '')" : "NULL"
  }

  private func isGroupChatExpression() -> String {
    "IFNULL(c.ZCONTACTJID, '') LIKE '%@g.us'"
  }

  /// `ZFROMJID` holds the group JID (not the author) for group messages, so it is only
  /// treated as the sender when it is not a group or broadcast JID.
  private func fromJIDSenderColumn() -> String {
    """
    CASE
      WHEN IFNULL(m.ZFROMJID, '') LIKE '%@g.us' OR IFNULL(m.ZFROMJID, '') LIKE '%@broadcast' THEN NULL
      ELSE NULLIF(m.ZFROMJID, '')
    END
    """
  }

  private func senderJIDExpression() -> String {
    """
    CASE
      WHEN IFNULL(m.ZISFROMME, 0) = 1 THEN NULL
      ELSE COALESCE(
        \(groupMemberJIDColumn()),
        \(fromJIDSenderColumn()),
        CASE WHEN \(isGroupChatExpression()) THEN NULL ELSE NULLIF(c.ZCONTACTJID, '') END
      )
    END
    """
  }

  private func senderExpression() -> String {
    """
    CASE
      WHEN IFNULL(m.ZISFROMME, 0) = 1 THEN 'me'
      ELSE COALESCE(\(senderJIDExpression()), '')
    END
    """
  }

  /// Newer WhatsApp builds store encoded blobs in `ZWAMESSAGE.ZPUSHNAME` and
  /// `ZWAGROUPMEMBER.ZFIRSTNAME`, so names are resolved from the chat, group member contact
  /// name, and profile push-name tables instead.
  private func senderNameExpression() -> String {
    let groupMemberContactName =
      schema.hasGroupMemberTable ? "NULLIF(gm.ZCONTACTNAME, '')" : "NULL"
    let pushName = schema.hasPushNameTable ? "NULLIF(pn.ZPUSHNAME, '')" : "NULL"
    return """
      CASE
        WHEN IFNULL(m.ZISFROMME, 0) = 1 THEN 'me'
        ELSE COALESCE(
          CASE WHEN \(isGroupChatExpression()) THEN NULL ELSE NULLIF(c.ZPARTNERNAME, '') END,
          \(groupMemberContactName),
          NULLIF(sc.ZPARTNERNAME, ''),
          \(pushName),
          ''
        )
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

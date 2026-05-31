import Foundation
import SQLite

extension WhatsAppStore {
  public func attachments(for messageID: Int64) throws -> [WhatsAppAttachment] {
    guard schema.hasMediaItemTable else { return [] }
    let sql = """
      SELECT mi.Z_PK AS attachment_id,
             ? AS message_id,
             IFNULL(mi.ZMEDIALOCALPATH, '') AS local_path,
             IFNULL(mi.ZTHUMBNAILLOCALPATH, '') AS thumbnail_path,
             IFNULL(mi.ZTITLE, '') AS title,
             IFNULL(mi.ZVCARDNAME, '') AS vcard_name,
             IFNULL(mi.ZFILESIZE, 0) AS file_size,
             IFNULL(mi.ZMEDIAURL, '') AS media_url
      FROM ZWAMEDIAITEM mi
      LEFT JOIN ZWAMESSAGE m ON m.Z_PK = ?
      WHERE mi.ZMESSAGE = ? OR (m.ZMEDIAITEM IS NOT NULL AND mi.Z_PK = m.ZMEDIAITEM)
      ORDER BY mi.Z_PK ASC
      """
    return try withConnection { db in
      var attachments: [WhatsAppAttachment] = []
      let rows = try db.prepareRowIterator(sql, bindings: [messageID, messageID, messageID])
      while let row = try rows.failableNext() {
        attachments.append(
          WhatsAppAttachment(
            id: try int64Value(row, "attachment_id") ?? 0,
            messageID: try int64Value(row, "message_id") ?? messageID,
            localPath: try stringValue(row, "local_path"),
            thumbnailPath: try stringValue(row, "thumbnail_path"),
            title: try stringValue(row, "title"),
            vCardName: try stringValue(row, "vcard_name"),
            fileSize: try int64Value(row, "file_size") ?? 0,
            mediaURL: try stringValue(row, "media_url")
          )
        )
      }
      return attachments
    }
  }
}


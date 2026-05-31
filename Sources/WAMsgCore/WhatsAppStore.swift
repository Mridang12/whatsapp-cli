import Dispatch
import Foundation
import SQLite

public final class WhatsAppStore: @unchecked Sendable {
  public static let appleEpochOffset: TimeInterval = 978_307_200
  public static let defaultPath = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent(
      "Library/Group Containers/group.net.whatsapp.WhatsApp.shared/ChatStorage.sqlite"
    )
    .path

  public let path: String
  let db: Connection
  let queue: DispatchQueue
  let schema: WhatsAppStoreSchema

  public convenience init(path: String = WhatsAppStore.defaultPath) throws {
    let expandedPath = (path as NSString).expandingTildeInPath
    do {
      let connection = try Connection(expandedPath, readonly: true)
      connection.busyTimeout = 5
      try self.init(connection: connection, path: expandedPath)
    } catch let error as WAMsgError {
      throw error
    } catch {
      throw WhatsAppStore.enhance(error: error, path: expandedPath)
    }
  }

  public init(connection: Connection, path: String = ":memory:") throws {
    self.path = path
    self.db = connection
    self.queue = DispatchQueue(label: "wmsg.store.\(UUID().uuidString)")
    self.schema = WhatsAppStoreSchema(connection: connection)
    guard schema.hasRequiredTables else {
      throw WAMsgError.invalidDatabase(
        path: path,
        reason: "expected ZWACHATSESSION and ZWAMESSAGE tables"
      )
    }
  }

  public func withConnection<T>(_ body: (Connection) throws -> T) rethrows -> T {
    try queue.sync {
      try body(db)
    }
  }
}

struct WhatsAppStoreSchema: Sendable {
  let tables: Set<String>
  let messageColumns: Set<String>
  let chatColumns: Set<String>
  let mediaColumns: Set<String>
  let groupMemberColumns: Set<String>
  let pushNameColumns: Set<String>

  var hasRequiredTables: Bool {
    tables.contains("zwachatsession") && tables.contains("zwamessage")
  }

  var hasMediaItemTable: Bool { tables.contains("zwamediaitem") }
  var hasGroupMemberTable: Bool { tables.contains("zwagroupmember") }
  var hasPushNameTable: Bool { tables.contains("zwaprofilepushname") }

  init(connection: Connection) {
    self.tables = WhatsAppStore.tableNames(connection: connection)
    self.messageColumns = WhatsAppStore.tableColumns(connection: connection, table: "ZWAMESSAGE")
    self.chatColumns = WhatsAppStore.tableColumns(connection: connection, table: "ZWACHATSESSION")
    self.mediaColumns = WhatsAppStore.tableColumns(connection: connection, table: "ZWAMEDIAITEM")
    self.groupMemberColumns = WhatsAppStore.tableColumns(
      connection: connection,
      table: "ZWAGROUPMEMBER"
    )
    self.pushNameColumns = WhatsAppStore.tableColumns(
      connection: connection,
      table: "ZWAPROFILEPUSHNAME"
    )
  }
}


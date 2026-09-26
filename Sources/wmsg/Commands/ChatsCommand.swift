import Foundation
import WAMsgCore

enum ChatsCommand {
  static let spec = CommandSpec(
    name: "chats",
    abstract: "List recent WhatsApp conversations",
    discussion: nil,
    signature: CommandSignatures.withRuntimeFlags(
      CommandSignature(
        options: CommandSignatures.baseOptions() + [
          .make(label: "limit", names: ["limit"], help: "number of chats to list")
        ],
        flags: [
          .make(
            label: "includeSystem",
            names: ["include-system"],
            help: "include WhatsApp status/broadcast pseudo-sessions"
          )
        ]
      )
    ),
    usageExamples: [
      "wmsg chats --limit 5",
      "wmsg chats --limit 5 --json",
    ]
  ) { values, runtime in
    try await run(values: values, runtime: runtime)
  }

  static func run(
    values: ParsedValues,
    runtime: RuntimeOptions,
    storeFactory: @escaping (String) throws -> WhatsAppStore = { try WhatsAppStore(path: $0) }
  ) async throws {
    let dbPath = values.option("db") ?? WhatsAppStore.defaultPath
    let limit = values.optionInt("limit") ?? 20
    let includeSystemChats = values.flag("includeSystem")
    let store = try storeFactory(dbPath)
    let chats = try store.listChats(limit: limit, includeSystemChats: includeSystemChats)

    if runtime.jsonOutput {
      for chat in chats {
        let participants = try store.participants(chatID: chat.id)
        try StdoutWriter.writeJSONLine(ChatPayload(chat: chat, participants: participants))
      }
      return
    }

    for chat in chats {
      let last = CLIISO8601.formatLocal(chat.lastMessageAt)
      let group = chat.isGroup ? " group" : ""
      let unread = chat.unreadCount > 0 ? " unread=\(chat.unreadCount)" : ""
      StdoutWriter.writeLine(
        "[\(chat.id)] \(chat.name) (\(chat.identifier)) last=\(last)\(group)\(unread)"
      )
    }
  }
}

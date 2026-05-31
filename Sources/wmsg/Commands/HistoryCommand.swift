import Foundation
import WAMsgCore

enum HistoryCommand {
  static let spec = CommandSpec(
    name: "history",
    abstract: "Show recent WhatsApp messages for a chat",
    discussion: nil,
    signature: CommandSignatures.withRuntimeFlags(
      CommandSignature(
        options: CommandSignatures.baseOptions() + [
          .make(label: "chatID", names: ["chat-id"], help: "chat rowid from 'wmsg chats'"),
          .make(label: "limit", names: ["limit"], help: "number of messages to show"),
          .make(
            label: "participants",
            names: ["participants"],
            help: "comma-separated sender JIDs to include"
          ),
          .make(label: "start", names: ["start"], help: "ISO8601 start (inclusive)"),
          .make(label: "end", names: ["end"], help: "ISO8601 end (exclusive)"),
        ],
        flags: [
          .make(label: "attachments", names: ["attachments"], help: "include attachment metadata")
        ]
      )
    ),
    usageExamples: [
      "wmsg history --chat-id 1 --limit 20",
      "wmsg history --chat-id 1 --start 2026-01-01T00:00:00Z --attachments --json",
    ]
  ) { values, runtime in
    try await run(values: values, runtime: runtime)
  }

  static func run(
    values: ParsedValues,
    runtime: RuntimeOptions,
    storeFactory: @escaping (String) throws -> WhatsAppStore = { try WhatsAppStore(path: $0) }
  ) async throws {
    guard let chatID = values.optionInt64("chatID") else {
      throw ParsedValuesError.missingOption("chat-id")
    }
    let dbPath = values.option("db") ?? WhatsAppStore.defaultPath
    let limit = values.optionInt("limit") ?? 50
    let includeAttachments = values.flag("attachments")
    let participants = values.optionValues("participants")
      .flatMap { $0.split(separator: ",").map { String($0) } }
      .filter { !$0.isEmpty }
    let filter = try WhatsAppMessageFilter.fromISO(
      participants: participants,
      startISO: values.option("start"),
      endISO: values.option("end")
    )

    let store = try storeFactory(dbPath)
    let messages = try store.messages(chatID: chatID, limit: limit, filter: filter)

    if runtime.jsonOutput {
      for message in messages {
        let attachments = includeAttachments ? try store.attachments(for: message.rowID) : nil
        try StdoutWriter.writeJSONLine(MessagePayload(message: message, attachments: attachments))
      }
      return
    }

    for message in messages {
      let direction = message.isFromMe ? "sent" : "recv"
      let timestamp = CLIISO8601.format(message.date)
      let sender = message.senderName ?? message.sender
      StdoutWriter.writeLine("\(timestamp) [\(direction)] \(sender): \(message.text)")
      if message.attachmentsCount > 0 {
        if includeAttachments {
          for attachment in try store.attachments(for: message.rowID) {
            StdoutWriter.writeLine(attachmentMetadataLine(for: attachment))
          }
        } else {
          StdoutWriter.writeLine(
            "  (\(message.attachmentsCount) attachment\(pluralSuffix(for: message.attachmentsCount)))"
          )
        }
      }
    }
  }

  private static func attachmentMetadataLine(for attachment: WhatsAppAttachment) -> String {
    let path = attachment.localPath.isEmpty ? attachment.mediaURL : attachment.localPath
    let title = attachment.title.isEmpty ? "attachment" : attachment.title
    return "  attachment \(attachment.id): \(title) \(path)"
  }

  private static func pluralSuffix(for count: Int) -> String {
    count == 1 ? "" : "s"
  }
}


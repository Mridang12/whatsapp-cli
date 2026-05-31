import Foundation
import WAMsgCore

enum WatchCommand {
  static let spec = CommandSpec(
    name: "watch",
    abstract: "Stream new WhatsApp messages",
    discussion: "Starts from the current newest row unless --from-row-id is provided.",
    signature: CommandSignatures.withRuntimeFlags(
      CommandSignature(
        options: CommandSignatures.baseOptions() + [
          .make(label: "chatID", names: ["chat-id"], help: "limit to chat rowid"),
          .make(label: "fromRowID", names: ["from-row-id"], help: "start after this message rowid"),
          .make(label: "pollInterval", names: ["poll-interval"], help: "poll interval in seconds"),
          .make(label: "batchLimit", names: ["batch-limit"], help: "maximum messages per poll"),
        ]
      )
    ),
    usageExamples: [
      "wmsg watch",
      "wmsg watch --chat-id 1 --json",
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
    let store = try storeFactory(dbPath)
    let watcher = WhatsAppWatcher(store: store)
    let configuration = WhatsAppWatcherConfiguration(
      pollInterval: values.optionDouble("pollInterval") ?? 0.5,
      batchLimit: values.optionInt("batchLimit") ?? 100
    )
    let stream = watcher.stream(
      chatID: values.optionInt64("chatID"),
      sinceRowID: values.optionInt64("fromRowID"),
      configuration: configuration
    )

    for try await message in stream {
      if runtime.jsonOutput {
        try StdoutWriter.writeJSONLine(MessagePayload(message: message))
      } else {
        let direction = message.isFromMe ? "sent" : "recv"
        let timestamp = CLIISO8601.format(message.date)
        let sender = message.senderName ?? message.sender
        StdoutWriter.writeLine("\(timestamp) [\(direction)] \(sender): \(message.text)")
      }
    }
  }
}


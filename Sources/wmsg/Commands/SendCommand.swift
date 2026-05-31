import Foundation
import WAMsgCore

enum SendCommand {
  static let spec = CommandSpec(
    name: "send",
    abstract: "Send a WhatsApp text message",
    discussion:
      "Uses WhatsApp.app UI automation, so the terminal needs Automation permission for WhatsApp and System Events.",
    signature: CommandSignatures.withRuntimeFlags(
      CommandSignature(
        options: CommandSignatures.baseOptions() + [
          .make(label: "to", names: ["to"], help: "contact or group name as shown in WhatsApp"),
          .make(label: "text", names: ["text"], help: "message body"),
          .make(label: "chatID", names: ["chat-id"], help: "chat rowid for verification"),
          .make(
            label: "searchDelay",
            names: ["search-delay"],
            help: "seconds to wait for WhatsApp search results"
          ),
          .make(
            label: "selectOffset",
            names: ["select-offset"],
            help: "down-arrow presses before opening a search result"
          ),
        ],
        flags: [
          .make(label: "verify", names: ["verify"], help: "verify the sent message in the DB"),
          .make(
            label: "noRestoreClipboard",
            names: ["no-restore-clipboard"],
            help: "leave the sent text on the clipboard"
          ),
        ]
      )
    ),
    usageExamples: [
      #"wmsg send --to "Jane Doe" --text "hello""#,
      #"wmsg send --to "Family" --text "hello" --verify --json"#,
    ]
  ) { values, runtime in
    try await run(values: values, runtime: runtime)
  }

  static func run(
    values: ParsedValues,
    runtime: RuntimeOptions,
    sendMessage: @escaping (WhatsAppSendOptions) throws -> Void = { try WhatsAppSender().send($0) },
    storeFactory: @escaping (String) throws -> WhatsAppStore = { try WhatsAppStore(path: $0) }
  ) async throws {
    let recipient = try values.optionRequired("to")
    let text = try values.optionRequired("text")
    let options = WhatsAppSendOptions(
      recipient: recipient,
      text: text,
      searchDelay: values.optionDouble("searchDelay") ?? 1.5,
      selectOffset: values.optionInt("selectOffset") ?? 2,
      restoreClipboard: !values.flag("noRestoreClipboard")
    )
    let sentAt = Date().addingTimeInterval(-2)
    try sendMessage(options)

    var sentMessage: WhatsAppMessage?
    if values.flag("verify") {
      let dbPath = values.option("db") ?? WhatsAppStore.defaultPath
      let store = try storeFactory(dbPath)
      sentMessage = try await resolveSentMessage(
        store: store,
        text: text,
        chatID: values.optionInt64("chatID"),
        since: sentAt
      )
    }

    if runtime.jsonOutput {
      try StdoutWriter.writeJSONLine(
        SendPayload(
          ok: true,
          recipient: recipient,
          text: text,
          sentMessage: sentMessage.map { MessagePayload(message: $0) }
        )
      )
      return
    }

    if let sentMessage {
      StdoutWriter.writeLine("sent to \(recipient) row_id=\(sentMessage.rowID)")
    } else {
      StdoutWriter.writeLine("sent to \(recipient)")
    }
  }

  private static func resolveSentMessage(
    store: WhatsAppStore,
    text: String,
    chatID: Int64?,
    since sentAt: Date
  ) async throws -> WhatsAppMessage? {
    let deadline = Date().addingTimeInterval(5)
    repeat {
      if let message = try store.latestSentMessage(text: text, chatID: chatID, since: sentAt) {
        return message
      }
      try await Task.sleep(nanoseconds: 300_000_000)
    } while Date() < deadline
    return nil
  }
}

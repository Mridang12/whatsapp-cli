import Foundation
import WAMsgCore

enum StatusCommand {
  static let spec = CommandSpec(
    name: "status",
    abstract: "Check WhatsApp database and automation status",
    discussion: nil,
    signature: CommandSignatures.withRuntimeFlags(
      CommandSignature(options: CommandSignatures.baseOptions())
    ),
    usageExamples: [
      "wmsg status",
      "wmsg status --json",
    ]
  ) { values, runtime in
    try await run(values: values, runtime: runtime)
  }

  static func run(
    values: ParsedValues,
    runtime: RuntimeOptions,
    storeFactory: @escaping (String) throws -> WhatsAppStore = { try WhatsAppStore(path: $0) },
    isWhatsAppRunning: @escaping () throws -> Bool = { try WhatsAppSender.isRunning() }
  ) async throws {
    let dbPath = values.option("db") ?? WhatsAppStore.defaultPath

    var databaseReadable = false
    var databaseError: String?
    do {
      let store = try storeFactory(dbPath)
      _ = try store.listChats(limit: 1)
      databaseReadable = true
    } catch {
      databaseError = String(describing: error)
    }

    var running: Bool?
    var automationError: String?
    do {
      running = try isWhatsAppRunning()
    } catch {
      automationError = String(describing: error)
    }

    if runtime.jsonOutput {
      try StdoutWriter.writeJSONLine(
        StatusPayload(
          databasePath: dbPath,
          databaseReadable: databaseReadable,
          databaseError: databaseError,
          whatsAppRunning: running,
          automationError: automationError
        )
      )
      return
    }

    StdoutWriter.writeLine("database: \(databaseReadable ? "ok" : "error") \(dbPath)")
    if let databaseError {
      StdoutWriter.writeLine("database_error: \(databaseError)")
    }
    if let running {
      StdoutWriter.writeLine("whatsapp_running: \(running ? "yes" : "no")")
    }
    if let automationError {
      StdoutWriter.writeLine("automation_error: \(automationError)")
    }
  }
}


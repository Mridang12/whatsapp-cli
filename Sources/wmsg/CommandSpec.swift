import Foundation

struct OptionDefinition: Sendable, Equatable {
  let label: String
  let names: [String]
  let help: String

  static func make(label: String, names: [String], help: String) -> OptionDefinition {
    OptionDefinition(label: label, names: names, help: help)
  }
}

struct FlagDefinition: Sendable, Equatable {
  let label: String
  let names: [String]
  let help: String

  static func make(label: String, names: [String], help: String) -> FlagDefinition {
    FlagDefinition(label: label, names: names, help: help)
  }
}

struct CommandSignature: Sendable, Equatable {
  let options: [OptionDefinition]
  let flags: [FlagDefinition]

  init(options: [OptionDefinition] = [], flags: [FlagDefinition] = []) {
    self.options = options
    self.flags = flags
  }
}

struct CommandSpec: @unchecked Sendable {
  let name: String
  let abstract: String
  let discussion: String?
  let signature: CommandSignature
  let usageExamples: [String]
  let run: (ParsedValues, RuntimeOptions) async throws -> Void
}

enum CommandSignatures {
  static func baseOptions() -> [OptionDefinition] {
    [
      .make(
        label: "db",
        names: ["db"],
        help:
          "Path to ChatStorage.sqlite (defaults to ~/Library/Group Containers/group.net.whatsapp.WhatsApp.shared/ChatStorage.sqlite)"
      )
    ]
  }

  static func withRuntimeFlags(_ signature: CommandSignature) -> CommandSignature {
    CommandSignature(
      options: signature.options,
      flags: signature.flags + [
        .make(label: "jsonOutput", names: ["json"], help: "emit newline-delimited JSON"),
        .make(label: "verbose", names: ["verbose"], help: "emit verbose diagnostics"),
      ]
    )
  }
}

struct RuntimeOptions: Sendable, Equatable {
  let jsonOutput: Bool
  let verbose: Bool

  init(parsedValues: ParsedValues) {
    self.jsonOutput = parsedValues.flag("jsonOutput")
    self.verbose = parsedValues.flag("verbose")
  }
}


import Testing
@testable import wmsg

@Test
func parserResolvesCommandOptionsAndFlags() throws {
  let router = CommandRouter()
  let (spec, values) = try router.resolve(
    argv: [
      "wmsg", "history", "--chat-id", "7", "--participants=me,+1555", "--attachments", "--json",
    ]
  )

  #expect(spec.name == "history")
  #expect(values.optionInt64("chatID") == 7)
  #expect(values.option("participants") == "me,+1555")
  #expect(values.flag("attachments"))
  #expect(RuntimeOptions(parsedValues: values).jsonOutput)
}

@Test
func parserRejectsUnknownOptions() throws {
  let router = CommandRouter()

  #expect(throws: ParsedValuesError.unknownOption("wat")) {
    _ = try router.resolve(argv: ["wmsg", "chats", "--wat"])
  }
}

@Test
func helpIncludesWhatsAppCommands() {
  let router = CommandRouter(version: "test")
  let lines = HelpPrinter.renderRoot(version: router.version, rootName: router.rootName, commands: router.specs)

  #expect(lines.contains { $0.contains("chats") })
  #expect(lines.contains { $0.contains("history") })
  #expect(lines.contains { $0.contains("send") })
}


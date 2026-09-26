import Foundation
import Testing
import WAMsgCore
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
func parserResolvesChatsIncludeSystemFlag() throws {
  let router = CommandRouter()
  let (spec, values) = try router.resolve(
    argv: ["wmsg", "chats", "--limit", "5", "--include-system"]
  )

  #expect(spec.name == "chats")
  #expect(values.optionInt("limit") == 5)
  #expect(values.flag("includeSystem"))
}

@Test
func parserResolvesSendLooseMatchFlag() throws {
  let router = CommandRouter()
  let (spec, values) = try router.resolve(
    argv: ["wmsg", "send", "--to", "Mom", "--text", "hi", "--allow-loose-match"]
  )

  #expect(spec.name == "send")
  #expect(values.option("to") == "Mom")
  #expect(values.flag("allowLooseMatch"))
}

@Test
func parserResolvesHistoryPagingOptions() throws {
  let router = CommandRouter()
  let (spec, values) = try router.resolve(
    argv: ["wmsg", "history", "--chat-id", "7", "--order", "oldest", "--after-id", "12", "--before-id", "40"]
  )

  #expect(spec.name == "history")
  #expect(try HistoryCommand.parseOrder(values.option("order")) == .oldestFirst)
  #expect(try HistoryCommand.parseOrder(nil) == .newestFirst)
  #expect(values.optionInt64("afterID") == 12)
  #expect(values.optionInt64("beforeID") == 40)
  #expect(throws: ParsedValuesError.invalidOption("order")) {
    _ = try HistoryCommand.parseOrder("sideways")
  }
}

@Test
func localTimestampsIncludeOffset() throws {
  let date = Date(timeIntervalSince1970: 1_790_000_000)
  let losAngeles = try #require(TimeZone(identifier: "America/Los_Angeles"))
  #expect(CLIISO8601.format(date) == "2026-09-21T14:13:20.000Z")
  #expect(CLIISO8601.formatLocal(date, timeZone: losAngeles) == "2026-09-21T07:13:20.000-07:00")
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

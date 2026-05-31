import Foundation
import Testing
@testable import WAMsgCore

final class ScriptCapture: @unchecked Sendable {
  var source = ""
  var arguments: [String] = []
}

@Test
func senderPassesRecipientAndTextToAppleScriptRunner() throws {
  let capture = ScriptCapture()
  let sender = WhatsAppSender { source, arguments in
    capture.source = source
    capture.arguments = arguments
    return "sent"
  }

  try sender.send(
    WhatsAppSendOptions(
      recipient: "Ada",
      text: "hello",
      searchDelay: 0.25,
      selectOffset: 3,
      restoreClipboard: false
    )
  )

  #expect(capture.source.contains("tell application \"WhatsApp\""))
  #expect(capture.arguments == ["Ada", "hello", "0.25", "3", "0"])
}

@Test
func senderValidatesRequiredInput() throws {
  let sender = WhatsAppSender { _, _ in "sent" }

  #expect(throws: WAMsgError.invalidSendTarget) {
    try sender.send(WhatsAppSendOptions(recipient: " ", text: "hello"))
  }
  #expect(throws: WAMsgError.invalidMessage) {
    try sender.send(WhatsAppSendOptions(recipient: "Ada", text: ""))
  }
}

@Test
func statusRunnerParsesBooleanOutput() throws {
  let running = try WhatsAppSender.isRunning(runner: { _, _ in "true\n" })
  let stopped = try WhatsAppSender.isRunning(runner: { _, _ in "false\n" })

  #expect(running)
  #expect(!stopped)
}

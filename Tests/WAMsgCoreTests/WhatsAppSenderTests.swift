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
      restoreClipboard: false,
      allowLooseMatch: true
    )
  )

  #expect(capture.source.contains("tell application \"WhatsApp\""))
  #expect(capture.arguments == ["Ada", "hello", "0.25", "3", "0", "1"])
}

@Test
func senderUsesWhatsAppURLForPhoneNumberTargets() throws {
  let capture = ScriptCapture()
  let sender = WhatsAppSender { source, arguments in
    capture.source = source
    capture.arguments = arguments
    return "sent"
  }

  try sender.send(
    WhatsAppSendOptions(
      recipient: "Mom",
      text: "hello world",
      phoneNumber: "+1 (555) 000-1111",
      searchDelay: 0.25
    )
  )

  #expect(capture.source.contains("open location"))
  #expect(capture.arguments[0].contains("whatsapp://send?"))
  #expect(capture.arguments[0].contains("phone=15550001111"))
  #expect(capture.arguments[0].contains("text=hello%20world"))
  #expect(capture.arguments[1] == "0.25")
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

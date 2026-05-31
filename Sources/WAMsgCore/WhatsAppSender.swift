import Foundation

#if os(macOS)
  import Carbon
#endif

public typealias WhatsAppAppleScriptRunner = @Sendable (String, [String]) throws -> String

public struct WhatsAppSendOptions: Sendable, Equatable {
  public let recipient: String
  public let text: String
  public let searchDelay: TimeInterval
  public let selectOffset: Int
  public let restoreClipboard: Bool

  public init(
    recipient: String,
    text: String,
    searchDelay: TimeInterval = 1.5,
    selectOffset: Int = 2,
    restoreClipboard: Bool = true
  ) {
    self.recipient = recipient
    self.text = text
    self.searchDelay = searchDelay
    self.selectOffset = selectOffset
    self.restoreClipboard = restoreClipboard
  }
}

public struct WhatsAppSender: Sendable {
  private let runner: WhatsAppAppleScriptRunner

  public init() {
    self.runner = WhatsAppSender.runAppleScript
  }

  init(runner: @escaping WhatsAppAppleScriptRunner) {
    self.runner = runner
  }

  public func send(_ options: WhatsAppSendOptions) throws {
    let recipient = options.recipient.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !recipient.isEmpty else { throw WAMsgError.invalidSendTarget }
    guard !options.text.isEmpty else { throw WAMsgError.invalidMessage }
    let arguments = [
      recipient,
      options.text,
      String(options.searchDelay),
      String(max(0, options.selectOffset)),
      options.restoreClipboard ? "1" : "0",
    ]
    _ = try runner(Self.sendScript, arguments)
  }

  public static func isRunning() throws -> Bool {
    try isRunning(runner: WhatsAppSender.runAppleScript)
  }

  static func isRunning(runner: WhatsAppAppleScriptRunner) throws -> Bool {
    let output = try runner(Self.statusScript, [])
    return output.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "true"
  }

  private static let statusScript = """
    on run argv
        tell application "System Events"
            return (exists process "WhatsApp") as string
        end tell
    end run
    """

  private static let sendScript = """
    on run argv
        set theRecipient to item 1 of argv
        set theMessage to item 2 of argv
        set searchDelay to (item 3 of argv) as real
        set selectOffset to (item 4 of argv) as integer
        set shouldRestoreClipboard to item 5 of argv

        tell application "WhatsApp" to activate
        delay 1

        tell application "System Events"
            if not (exists process "WhatsApp") then error "WhatsApp process is not running"
            tell process "WhatsApp"
                set frontmost to true
                keystroke "f" using {command down}
                delay 0.3
                keystroke "a" using {command down}
                key code 51
                delay 0.2
                keystroke theRecipient
                delay searchDelay

                repeat selectOffset times
                    key code 125
                    delay 0.15
                end repeat
                key code 36
                delay 0.7

                set savedClipboard to missing value
                if shouldRestoreClipboard is "1" then
                    try
                        set savedClipboard to the clipboard
                    end try
                end if

                set the clipboard to theMessage
                keystroke "v" using {command down}
                delay 0.2
                key code 36
                delay 0.2

                if shouldRestoreClipboard is "1" then
                    try
                        if savedClipboard is not missing value then set the clipboard to savedClipboard
                    end try
                end if
            end tell
        end tell
        return "sent"
    end run
    """

  private static func runAppleScript(source: String, arguments: [String]) throws -> String {
    #if os(macOS)
      guard let script = NSAppleScript(source: source) else {
        throw WAMsgError.appleScriptFailure("Unable to compile AppleScript")
      }
      var errorInfo: NSDictionary?
      let event = NSAppleEventDescriptor(
        eventClass: AEEventClass(kASAppleScriptSuite),
        eventID: AEEventID(kASSubroutineEvent),
        targetDescriptor: nil,
        returnID: AEReturnID(kAutoGenerateReturnID),
        transactionID: AETransactionID(kAnyTransactionID)
      )
      event.setParam(
        NSAppleEventDescriptor(string: "run"),
        forKeyword: AEKeyword(keyASSubroutineName)
      )
      let list = NSAppleEventDescriptor.list()
      for (index, value) in arguments.enumerated() {
        list.insert(NSAppleEventDescriptor(string: value), at: index + 1)
      }
      event.setParam(list, forKeyword: keyDirectObject)
      let result = script.executeAppleEvent(event, error: &errorInfo)
      if let errorInfo {
        if shouldFallbackToOsascript(errorInfo: errorInfo) {
          return try runOsascript(source: source, arguments: arguments)
        }
        let message =
          (errorInfo[NSAppleScript.errorMessage] as? String) ?? "Unknown AppleScript error"
        throw WAMsgError.appleScriptFailure(message)
      }
      return result.stringValue ?? ""
    #else
      _ = source
      _ = arguments
      throw WAMsgError.appleScriptFailure(
        "Sending requires WhatsApp.app automation and is only supported on macOS."
      )
    #endif
  }

  private static func shouldFallbackToOsascript(errorInfo: NSDictionary) -> Bool {
    #if os(macOS)
      if let errorNumber = errorInfo[NSAppleScript.errorNumber] as? Int, errorNumber == -1743 {
        return true
      }
      if errorInfo[NSAppleScript.errorMessage] == nil {
        return true
      }
      if let message = errorInfo[NSAppleScript.errorMessage] as? String {
        let lower = message.lowercased()
        return lower.contains("not authorized") || lower.contains("not authorised")
      }
      return false
    #else
      _ = errorInfo
      return false
    #endif
  }

  private static func runOsascript(source: String, arguments: [String]) throws -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    process.arguments = ["-l", "AppleScript", "-"] + arguments
    let stdinPipe = Pipe()
    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    process.standardInput = stdinPipe
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe
    try process.run()
    if let data = source.data(using: .utf8) {
      stdinPipe.fileHandleForWriting.write(data)
    }
    stdinPipe.fileHandleForWriting.closeFile()
    process.waitUntilExit()
    let stdout = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
    if process.terminationStatus != 0 {
      let data = stderrPipe.fileHandleForReading.readDataToEndOfFile()
      let message = String(data: data, encoding: .utf8) ?? "Unknown osascript error"
      throw WAMsgError.appleScriptFailure(message.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    return String(data: stdout, encoding: .utf8) ?? ""
  }
}

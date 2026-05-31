import Foundation

struct HelpPrinter {
  static func printRoot(version: String, rootName: String, commands: [CommandSpec]) {
    for line in renderRoot(version: version, rootName: rootName, commands: commands) {
      StdoutWriter.writeLine(line)
    }
  }

  static func printCommand(rootName: String, spec: CommandSpec) {
    for line in renderCommand(rootName: rootName, spec: spec) {
      StdoutWriter.writeLine(line)
    }
  }

  static func renderRoot(version: String, rootName: String, commands: [CommandSpec]) -> [String] {
    var lines: [String] = []
    lines.append("\(rootName) \(version)")
    lines.append("Read local WhatsApp messages and send WhatsApp texts from the terminal")
    lines.append("")
    lines.append("Usage:")
    lines.append("  \(rootName) <command> [options]")
    lines.append("")
    lines.append("Commands:")
    for command in commands {
      lines.append("  \(command.name)\t\(command.abstract)")
    }
    lines.append("")
    lines.append("Run '\(rootName) <command> --help' for details.")
    return lines
  }

  static func renderCommand(rootName: String, spec: CommandSpec) -> [String] {
    var lines: [String] = []
    lines.append("\(rootName) \(spec.name)")
    lines.append(spec.abstract)
    if let discussion = spec.discussion, !discussion.isEmpty {
      lines.append("\n\(discussion)")
    }
    lines.append("")
    lines.append("Usage:")
    lines.append("  \(rootName) \(spec.name) [options]")
    lines.append("")

    let options = spec.signature.options
    let flags = spec.signature.flags
    if !options.isEmpty || !flags.isEmpty {
      lines.append("Options:")
      for option in options {
        lines.append("  \(formatNames(option.names, expectsValue: true))\t\(option.help)")
      }
      for flag in flags {
        lines.append("  \(formatNames(flag.names, expectsValue: false))\t\(flag.help)")
      }
      lines.append("")
    }

    if !spec.usageExamples.isEmpty {
      lines.append("Examples:")
      for example in spec.usageExamples {
        lines.append("  \(example)")
      }
    }
    return lines
  }

  private static func formatNames(_ names: [String], expectsValue: Bool) -> String {
    let suffix = expectsValue ? " <value>" : ""
    return names.map { "--\($0)" }.joined(separator: ", ") + suffix
  }
}


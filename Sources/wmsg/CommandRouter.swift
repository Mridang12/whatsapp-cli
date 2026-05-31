import Foundation

struct CommandRouter {
  let rootName = "wmsg"
  let version: String
  let specs: [CommandSpec]

  init(version: String = "0.1.0") {
    self.version = version
    self.specs = [
      ChatsCommand.spec,
      HistoryCommand.spec,
      WatchCommand.spec,
      SendCommand.spec,
      StatusCommand.spec,
    ]
  }

  func run() async -> Int32 {
    await run(argv: CommandLine.arguments)
  }

  func run(argv: [String]) async -> Int32 {
    let argv = normalizeArguments(argv)
    if argv.contains("--version") || argv.contains("-V") {
      StdoutWriter.writeLine(version)
      return 0
    }
    if argv.count <= 1 || argv.contains("--help") || argv.contains("-h") {
      printHelp(for: argv)
      return 0
    }

    do {
      let (spec, parsedValues) = try resolve(argv: argv)
      let runtime = RuntimeOptions(parsedValues: parsedValues)
      try await spec.run(parsedValues, runtime)
      return 0
    } catch {
      StdoutWriter.writeLine(String(describing: error))
      return 1
    }
  }

  func resolve(argv: [String]) throws -> (CommandSpec, ParsedValues) {
    guard argv.count > 1 else {
      throw ParsedValuesError.missingArgument("command")
    }
    let commandName = argv[1]
    guard let spec = specs.first(where: { $0.name == commandName }) else {
      throw ParsedValuesError.missingArgument("known command")
    }

    var optionByName: [String: String] = [:]
    for option in spec.signature.options {
      for name in option.names {
        optionByName[name] = option.label
      }
    }
    var flagByName: [String: String] = [:]
    for flag in spec.signature.flags {
      for name in flag.names {
        flagByName[name] = flag.label
      }
    }

    var parsed = ParsedValues()
    var index = 2
    while index < argv.count {
      let token = argv[index]
      if token == "--" {
        parsed.positional.append(contentsOf: argv[(index + 1)...])
        break
      }
      guard token.hasPrefix("--") else {
        parsed.positional.append(token)
        index += 1
        continue
      }

      let raw = String(token.dropFirst(2))
      let parts = raw.split(separator: "=", maxSplits: 1).map(String.init)
      let name = parts[0]
      if let label = flagByName[name] {
        if parts.count > 1 {
          throw ParsedValuesError.invalidOption(name)
        }
        parsed.flags.insert(label)
        index += 1
        continue
      }
      guard let label = optionByName[name] else {
        throw ParsedValuesError.unknownOption(name)
      }
      let value: String
      if parts.count == 2 {
        value = parts[1]
      } else {
        let valueIndex = index + 1
        guard valueIndex < argv.count, !argv[valueIndex].hasPrefix("--") else {
          throw ParsedValuesError.missingOption(name)
        }
        value = argv[valueIndex]
        index += 1
      }
      parsed.options[label, default: []].append(value)
      index += 1
    }
    return (spec, parsed)
  }

  private func normalizeArguments(_ argv: [String]) -> [String] {
    guard !argv.isEmpty else { return argv }
    var copy = argv
    copy[0] = URL(fileURLWithPath: argv[0]).lastPathComponent
    return copy
  }

  private func printHelp(for argv: [String]) {
    let path = helpPath(from: argv)
    if path.count <= 1 {
      HelpPrinter.printRoot(version: version, rootName: rootName, commands: specs)
      return
    }
    if let spec = specs.first(where: { $0.name == path[1] }) {
      HelpPrinter.printCommand(rootName: rootName, spec: spec)
    } else {
      HelpPrinter.printRoot(version: version, rootName: rootName, commands: specs)
    }
  }

  private func helpPath(from argv: [String]) -> [String] {
    var path: [String] = []
    for token in argv {
      if token == "--help" || token == "-h" { continue }
      if token.hasPrefix("-") { break }
      path.append(token)
    }
    return path
  }
}


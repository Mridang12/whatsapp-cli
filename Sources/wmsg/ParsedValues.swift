import Foundation

enum ParsedValuesError: Error, CustomStringConvertible, Equatable {
  case missingOption(String)
  case invalidOption(String)
  case unknownOption(String)
  case missingArgument(String)

  var description: String {
    switch self {
    case .missingOption(let name):
      return "Missing required option: --\(name)"
    case .invalidOption(let name):
      return "Invalid value for option: --\(name)"
    case .unknownOption(let name):
      return "Unknown option: --\(name)"
    case .missingArgument(let name):
      return "Missing required argument: \(name)"
    }
  }
}

struct ParsedValues: Sendable, Equatable {
  var options: [String: [String]] = [:]
  var flags: Set<String> = []
  var positional: [String] = []

  func flag(_ label: String) -> Bool {
    flags.contains(label)
  }

  func option(_ label: String) -> String? {
    options[label]?.last
  }

  func optionValues(_ label: String) -> [String] {
    options[label] ?? []
  }

  func optionInt(_ label: String) -> Int? {
    guard let value = option(label) else { return nil }
    return Int(value)
  }

  func optionInt64(_ label: String) -> Int64? {
    guard let value = option(label) else { return nil }
    return Int64(value)
  }

  func optionDouble(_ label: String) -> Double? {
    guard let value = option(label) else { return nil }
    return Double(value)
  }

  func optionRequired(_ label: String, optionName: String? = nil) throws -> String {
    guard let value = option(label), !value.isEmpty else {
      throw ParsedValuesError.missingOption(optionName ?? label)
    }
    return value
  }

  func argument(_ index: Int) -> String? {
    guard positional.indices.contains(index) else { return nil }
    return positional[index]
  }
}


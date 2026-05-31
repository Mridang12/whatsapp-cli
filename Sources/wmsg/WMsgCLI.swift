import Foundation

@main
struct WMsgCLI {
  static func main() async {
    exit(await CommandRouter().run())
  }
}


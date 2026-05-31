// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "whatsapp-cli",
  platforms: [.macOS(.v14)],
  products: [
    .library(name: "WAMsgCore", targets: ["WAMsgCore"]),
    .executable(name: "wmsg", targets: ["wmsg"]),
  ],
  dependencies: [
    .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.15.5")
  ],
  targets: [
    .target(
      name: "WAMsgCore",
      dependencies: [
        .product(name: "SQLite", package: "SQLite.swift")
      ]
    ),
    .executableTarget(
      name: "wmsg",
      dependencies: [
        "WAMsgCore"
      ],
      exclude: [
        "Resources/Info.plist"
      ],
      linkerSettings: [
        .unsafeFlags(
          [
            "-Xlinker", "-sectcreate",
            "-Xlinker", "__TEXT",
            "-Xlinker", "__info_plist",
            "-Xlinker", "Sources/wmsg/Resources/Info.plist",
          ],
          .when(platforms: [.macOS])
        )
      ]
    ),
    .testTarget(
      name: "WAMsgCoreTests",
      dependencies: [
        "WAMsgCore",
        .product(name: "SQLite", package: "SQLite.swift"),
      ]
    ),
    .testTarget(
      name: "wmsgTests",
      dependencies: [
        "wmsg",
        "WAMsgCore",
        .product(name: "SQLite", package: "SQLite.swift"),
      ]
    ),
  ]
)

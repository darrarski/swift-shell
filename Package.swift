// swift-tools-version: 5.10
import PackageDescription

let package = Package(
  name: "swift-shell",
  platforms: [
    .macOS(.v14),
  ],
  products: [
    .library(name: "SwiftShell", targets: ["SwiftShell"]),
  ],
  dependencies: [
    .package(url: "https://github.com/pointfreeco/swift-concurrency-extras.git", from: "1.1.0"),
    .package(url: "https://github.com/pointfreeco/swift-custom-dump.git", from: "1.3.0"),
  ],
  targets: [
    .target(
      name: "SwiftShell"
    ),
    .testTarget(
      name: "SwiftShellTests",
      dependencies: [
        .target(name: "SwiftShell"),
        .product(name: "ConcurrencyExtras", package: "swift-concurrency-extras"),
        .product(name: "CustomDump", package: "swift-custom-dump"),
      ]
    ),
  ]
)

extension Target {
  var isLocal: Bool { ![.binary, .system].contains(self.type) }
}

extension BuildSettingCondition {
  static let whenDebug = BuildSettingCondition.when(configuration: .debug)
}

extension SwiftSetting {
  static func enableActorDataRaceChecks(_ condition: BuildSettingCondition? = nil) -> SwiftSetting {
    .unsafeFlags(["-Xfrontend", "-enable-actor-data-race-checks"], condition)
  }
  static func debugTime(_ condition: BuildSettingCondition? = nil) -> SwiftSetting {
    .unsafeFlags(
      ["-Xfrontend", "-debug-time-function-bodies",
       "-Xfrontend", "-debug-time-expression-type-checking"],
      condition
    )
  }
}

for target in package.targets where target.isLocal {
  var swiftSettings = target.swiftSettings ?? []
  swiftSettings.append(.enableActorDataRaceChecks(.whenDebug))
  swiftSettings.append(.debugTime(.whenDebug))
#if !hasFeature(StrictConcurrency)
  swiftSettings.append(.enableUpcomingFeature("StrictConcurrency", .whenDebug))
  swiftSettings.append(.enableExperimentalFeature("StrictConcurrency", .whenDebug))
#endif
#if !hasFeature(GlobalConcurrency)
  swiftSettings.append(.enableUpcomingFeature("GlobalConcurrency", .whenDebug))
#endif
#if !hasFeature(InternalImportsByDefault)
  swiftSettings.append(.enableUpcomingFeature("InternalImportsByDefault", .whenDebug))
#endif
  target.swiftSettings = swiftSettings
}

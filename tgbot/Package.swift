// swift-tools-version:5.9
import PackageDescription

let swiftSettings: [SwiftSetting] = [
    .enableExperimentalFeature("ExistentialAny"),
]

let package = Package(
    name: "tgbot",
    platforms: [
       .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", .upToNextMajor(from: "4.57.0")),
        .package(url: "https://github.com/nerzh/swift-telegram-sdk", .upToNextMajor(from: "3.0.3")),
    ],
    targets: [
        .executableTarget(
            name: "tgbot",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "SwiftTelegramSdk", package: "swift-telegram-sdk"),
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "tgbotTests",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "SwiftTelegramSdk", package: "swift-telegram-sdk"),
            ],
            swiftSettings: swiftSettings
        )
    ]
)

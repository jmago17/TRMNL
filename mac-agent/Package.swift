// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "TRMNLMacAgent",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "trmnl-mac-agent", targets: ["TRMNLMacAgent"])
    ],
    targets: [
        .executableTarget(
            name: "TRMNLMacAgent",
            path: "Sources/TRMNLMacAgent",
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Info.plist"
                ])
            ]
        )
    ]
)

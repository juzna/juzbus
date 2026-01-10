// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "juzbus",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "JuzbusProtocols",
            targets: ["JuzbusProtocols"]
        ),
        .executable(
            name: "juzbus-directory",
            targets: ["JuzbusDirectory"]
        ),
        .executable(
            name: "juzbus",
            targets: ["JuzbusCLI"]
        ),
        .executable(
            name: "juzbus-example",
            targets: ["JuzbusExample"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "JuzbusProtocols",
            dependencies: []
        ),
        .executableTarget(
            name: "JuzbusDirectory",
            dependencies: ["JuzbusProtocols"]
        ),
        .executableTarget(
            name: "JuzbusCLI",
            dependencies: ["JuzbusProtocols"]
        ),
        .executableTarget(
            name: "JuzbusExample",
            dependencies: ["JuzbusProtocols"]
        ),
    ]
)

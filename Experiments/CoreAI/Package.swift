// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KerjaInCoreAIExperiment",
    platforms: [.macOS("27.0")],
    dependencies: [
        .package(url: "https://github.com/apple/coreai-models.git",
                 revision: "3efa838ebf1a1e816ef4c17eb5022fe22cda2cb9")
    ],
    targets: [
        .executableTarget(
            name: "coreai-experiment",
            dependencies: [.product(name: "CoreAILM", package: "coreai-models")]
        )
    ]
)

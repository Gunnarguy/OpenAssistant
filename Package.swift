// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "OpenAssistant",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "OpenAssistant",
            targets: ["OpenAssistant"])
    ],
    targets: [
        .target(
            name: "OpenAssistant",
            path: "OpenAssistant"
        )
    ]
)

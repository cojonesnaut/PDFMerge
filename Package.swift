// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "PDFMerge",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "PDFMerge",
            path: "Sources/PDFMerge",
            swiftSettings: [.unsafeFlags(["-Osize"])]
        )
    ]
)

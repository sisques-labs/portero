// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Portero",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Portero",
            path: "Sources/Portero"
        )
    ]
)

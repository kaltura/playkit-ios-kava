// swift-tools-version:5.2
import PackageDescription

let package = Package(
    name: "PlayKitKava",
    platforms: [
        .iOS(.v9), .tvOS(.v9)
    ],
    products: [
        .library(
            name: "PlayKitKava",
            targets: ["PlayKitKava"]),
    ],
    dependencies: [
        .package(name: "PlayKit", url: "https://github.com/kaltura/playkit-ios.git", .branch("spm")),
    ],
    targets: [
        .target(
            name: "PlayKitKava",
            dependencies: [
                "PlayKit",
            ],
            path: "Sources"
        )
    ]
)

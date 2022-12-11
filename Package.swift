// swift-tools-version:5.3

import PackageDescription

let package = Package( 
    name: "PlayKitKava",
    platforms: [.iOS(.v11),
                .tvOS(.v11)],
    products: [.library(name: "PlayKitKava",
                        targets: ["PlayKitKava"])],
    dependencies: [
        .package(name: "PlayKit",
                 url: "https://github.com/kaltura/playkit-ios.git",
                 .branch("FEC-12640")),
    ],
    targets: [.target(name: "PlayKitKava",
                      dependencies:
                        [
//                            .product(name: "PlayKit", package: "PlayKit"),
                            .product(name: "AnalyticsCommon", package: "PlayKit"),
                        ],
                      path: "Sources/")
    ]
)

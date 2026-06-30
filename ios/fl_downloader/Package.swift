// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "fl_downloader",
    platforms: [
        .iOS("13.0")
    ],
    products: [
        .library(name: "fl-downloader", targets: ["fl_downloader"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "fl_downloader",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ],
            resources: [
                .process("PrivacyInfo.xcprivacy"),
            ]
        )
    ]
)

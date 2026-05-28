// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "ClipX",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "ClipXCore", targets: ["ClipXCore"]),
        .executable(name: "ClipX", targets: ["ClipXApp"]),
        .executable(name: "ClipXCoreTestRunner", targets: ["ClipXCoreTestRunner"])
    ],
    targets: [
        .target(
            name: "ClipXCore",
            linkerSettings: [
                .linkedFramework("Security"),
                .linkedLibrary("sqlite3")
            ]
        ),
        .executableTarget(
            name: "ClipXApp",
            dependencies: ["ClipXCore"],
            resources: [
                .process("Resources")
            ]
        ),
        .executableTarget(
            name: "ClipXCoreTestRunner",
            dependencies: ["ClipXCore"]
        )
    ]
)

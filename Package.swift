// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "AutoClicker",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "AutoClicker", targets: ["AutoClicker"])
    ],
    targets: [
        .executableTarget(
            name: "AutoClicker",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("Carbon")
            ]
        )
    ]
)

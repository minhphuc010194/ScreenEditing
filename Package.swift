// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Presentify",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "CoreEngine", targets: ["CoreEngine"]),
        .library(name: "PresentifyCore", targets: ["PresentifyCore"]),
        .executable(name: "Presentify", targets: ["Presentify"])
    ],
    targets: [
        .target(
            name: "CoreEngine",
            path: "Sources/CoreEngine",
            publicHeadersPath: "include"
        ),
        .target(
            name: "PresentifyCore",
            dependencies: ["CoreEngine"],
            path: "Sources/PresentifyCore",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("ScreenCaptureKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("QuartzCore"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("UserNotifications")
            ]
        ),
        .executableTarget(
            name: "Presentify",
            dependencies: ["PresentifyCore"],
            path: "Sources/Presentify"
        ),
        .testTarget(
            name: "PresentifyTests",
            dependencies: ["CoreEngine", "PresentifyCore"],
            path: "Tests/PresentifyTests"
        )
    ],
    cxxLanguageStandard: .cxx20
)

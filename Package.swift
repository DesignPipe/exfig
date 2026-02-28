// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "exfig",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(name: "exfig", targets: ["ExFigCLI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-collections", "1.2.0" ..< "1.3.0"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.6.0"),
        .package(url: "https://github.com/huggingface/swift-jinja.git", from: "2.0.0"),
        .package(url: "https://github.com/tuist/XcodeProj.git", from: "8.27.0"),
        .package(url: "https://github.com/pointfreeco/swift-custom-dump", from: "1.3.0"),

        .package(url: "https://github.com/the-swift-collective/libwebp.git", from: "1.4.1"),
        .package(url: "https://github.com/the-swift-collective/libpng.git", from: "1.6.45"),
        .package(url: "https://github.com/tuist/Noora", from: "0.54.0"),
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.4.5"),
        .package(url: "https://github.com/alexey1312/swift-resvg.git", exact: "0.45.1-swift.3"),
        .package(url: "https://github.com/mattt/swift-yyjson", from: "0.5.0"),
        .package(url: "https://github.com/apple/pkl-swift", from: "0.8.0"),
    ],
    targets: [
        // Main target
        .executableTarget(
            name: "ExFigCLI",
            dependencies: [
                "FigmaAPI",
                "ExFigCore",
                "ExFigConfig",
                "XcodeExport",
                "AndroidExport",
                "FlutterExport",
                "WebExport",
                "SVGKit",
                "ExFig-iOS",
                "ExFig-Android",
                "ExFig-Flutter",
                "ExFig-Web",
                .product(name: "Resvg", package: "swift-resvg"),
                .product(name: "XcodeProj", package: "XcodeProj"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Logging", package: "swift-log"),

                .product(name: "WebP", package: "libwebp"),
                .product(name: "LibPNG", package: "libpng"),
                .product(name: "Noora", package: "Noora"),
            ],
            exclude: ["CLAUDE.md", "AGENTS.md"],
            resources: [
                .copy("Resources/Schemas/"),
            ]
        ),

        // Shared target
        .target(
            name: "ExFigCore",
            dependencies: [
                .product(name: "YYJSON", package: "swift-yyjson"),
            ],
            exclude: ["CLAUDE.md", "AGENTS.md"]
        ),

        // PKL configuration and shared config types
        .target(
            name: "ExFigConfig",
            dependencies: [
                "ExFigCore",
                .product(name: "PklSwift", package: "pkl-swift"),
            ],
            exclude: ["CLAUDE.md", "AGENTS.md"]
        ),

        // Loads data via Figma REST API
        .target(
            name: "FigmaAPI",
            dependencies: [
                "ExFigCore",
            ],
            exclude: ["CLAUDE.md", "AGENTS.md"]
        ),

        // Shared Jinja template rendering utilities
        .target(
            name: "JinjaSupport",
            dependencies: [
                .product(name: "Jinja", package: "swift-jinja"),
            ],
            exclude: ["CLAUDE.md", "AGENTS.md"]
        ),

        // Exports resources to Xcode project
        .target(
            name: "XcodeExport",
            dependencies: [
                "ExFigCore",
                "JinjaSupport",
            ],
            exclude: ["CLAUDE.md", "AGENTS.md"],
            resources: [
                .copy("Resources/"),
            ]
        ),

        // SVG parsing and code generation
        .target(
            name: "SVGKit",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Resvg", package: "swift-resvg"),
            ],
            exclude: ["CLAUDE.md", "AGENTS.md"]
        ),

        // Exports resources to Android project
        .target(
            name: "AndroidExport",
            dependencies: [
                "ExFigCore",
                "SVGKit",
                "JinjaSupport",
                .product(name: "OrderedCollections", package: "swift-collections"),
            ],
            exclude: ["CLAUDE.md", "AGENTS.md"],
            resources: [
                .copy("Resources/"),
            ]
        ),

        // Exports resources to Flutter project
        .target(
            name: "FlutterExport",
            dependencies: [
                "ExFigCore",
                "JinjaSupport",
            ],
            exclude: ["CLAUDE.md", "AGENTS.md"],
            resources: [
                .copy("Resources/"),
            ]
        ),

        // Exports resources to Web/React project
        .target(
            name: "WebExport",
            dependencies: [
                "ExFigCore",
                "JinjaSupport",
            ],
            exclude: ["CLAUDE.md", "AGENTS.md"],
            resources: [
                .copy("Resources/"),
            ]
        ),

        // MARK: - Platform Plugins

        // iOS platform plugin
        .target(
            name: "ExFig-iOS",
            dependencies: [
                "ExFigCore",
                "ExFigConfig",
                "XcodeExport",
            ],
            exclude: ["CLAUDE.md", "AGENTS.md"]
        ),

        // Android platform plugin
        .target(
            name: "ExFig-Android",
            dependencies: [
                "ExFigCore",
                "ExFigConfig",
                "AndroidExport",
                "SVGKit",
            ],
            exclude: ["CLAUDE.md", "AGENTS.md"]
        ),

        // Flutter platform plugin
        .target(
            name: "ExFig-Flutter",
            dependencies: [
                "ExFigCore",
                "ExFigConfig",
                "FlutterExport",
            ],
            exclude: ["CLAUDE.md", "AGENTS.md"]
        ),

        // Web platform plugin
        .target(
            name: "ExFig-Web",
            dependencies: [
                "ExFigCore",
                "ExFigConfig",
                "WebExport",
            ],
            exclude: ["CLAUDE.md", "AGENTS.md"]
        ),

        // MARK: - Tests

        .testTarget(
            name: "FigmaAPITests",
            dependencies: [
                "FigmaAPI",
                .product(name: "CustomDump", package: "swift-custom-dump"),
            ],
            resources: [
                .copy("Fixtures/"),
            ]
        ),
        .testTarget(
            name: "ExFigTests",
            dependencies: [
                "ExFigCLI",
                "FigmaAPI",
                "ExFig-Flutter",
                "ExFig-Web",
                .product(name: "CustomDump", package: "swift-custom-dump"),
                .product(name: "LibPNG", package: "libpng"),
            ],
            resources: [
                .copy("Fixtures/"),
            ]
        ),
        .testTarget(
            name: "JinjaSupportTests",
            dependencies: ["JinjaSupport"]
        ),
        .testTarget(
            name: "ExFigCoreTests",
            dependencies: [
                "ExFigCore",
                .product(name: "CustomDump", package: "swift-custom-dump"),
            ]
        ),
        .testTarget(
            name: "XcodeExportTests",
            dependencies: [
                "XcodeExport",
                .product(name: "CustomDump", package: "swift-custom-dump"),
            ]
        ),
        .testTarget(
            name: "AndroidExportTests",
            dependencies: [
                "AndroidExport",
                .product(name: "CustomDump", package: "swift-custom-dump"),
                .product(name: "OrderedCollections", package: "swift-collections"),
            ]
        ),
        .testTarget(
            name: "FlutterExportTests",
            dependencies: [
                "FlutterExport", .product(name: "CustomDump", package: "swift-custom-dump"),
            ]
        ),
        .testTarget(
            name: "WebExportTests",
            dependencies: [
                "WebExport", .product(name: "CustomDump", package: "swift-custom-dump"),
            ]
        ),
        .testTarget(
            name: "SVGKitTests",
            dependencies: ["SVGKit", .product(name: "CustomDump", package: "swift-custom-dump")]
        ),

        // MARK: - Plugin Tests

        .testTarget(
            name: "ExFig-iOSTests",
            dependencies: [
                "ExFig-iOS",
                "ExFigCore",
                .product(name: "CustomDump", package: "swift-custom-dump"),
            ]
        ),
        .testTarget(
            name: "ExFig-AndroidTests",
            dependencies: [
                "ExFig-Android",
                "ExFigCore",
                .product(name: "CustomDump", package: "swift-custom-dump"),
            ]
        ),
        .testTarget(
            name: "ExFig-FlutterTests",
            dependencies: [
                "ExFig-Flutter",
                "ExFigCore",
                .product(name: "CustomDump", package: "swift-custom-dump"),
            ]
        ),
        .testTarget(
            name: "ExFig-WebTests",
            dependencies: [
                "ExFig-Web",
                "ExFigCore",
                .product(name: "CustomDump", package: "swift-custom-dump"),
            ]
        ),
    ]
)

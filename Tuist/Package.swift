// swift-tools-version: 6.1
import PackageDescription

#if TUIST
import struct ProjectDescription.PackageSettings

let packageSettings = PackageSettings(
    productTypes: [
        "Dependencies": .staticFramework,
        "DependenciesMacros": .staticFramework,
        "Sharing": .staticFramework,
        "IdentifiedCollections": .staticFramework,
        "OrderedCollections": .staticFramework,
        "CasePaths": .staticFramework,
        "SwiftNavigation": .staticFramework,
        "SwiftUINavigation": .staticFramework,
        "Tagged": .staticFramework,
        "IssueReporting": .staticFramework,
        "KeyboardShortcuts": .staticFramework,
        "SQLiteData": .staticFramework,
        "StructuredQueries": .staticFramework,
        "HighlightSwift": .staticFramework,
    ],
    // Tuist resolves the package graph but does not forward SPM traits to the
    // generated targets, so the `Tagged` condition has to be set by hand.
    targetSettings: [
        "StructuredQueriesCore": ["SWIFT_ACTIVE_COMPILATION_CONDITIONS": "$(inherited) Tagged"],
        "SQLiteData": ["SWIFT_ACTIVE_COMPILATION_CONDITIONS": "$(inherited) Tagged"],
    ]
)
#endif

let package = Package(
    name: "FlareDeps",
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.17.1"),
        .package(url: "https://github.com/pointfreeco/swift-sharing", from: "2.10.0"),
        .package(url: "https://github.com/pointfreeco/swift-identified-collections", from: "1.1.1"),
        .package(url: "https://github.com/pointfreeco/swift-case-paths", from: "1.10.0"),
        .package(url: "https://github.com/pointfreeco/swift-navigation", from: "2.11.1"),
        .package(url: "https://github.com/pointfreeco/swift-tagged", from: "0.10.0"),
        .package(url: "https://github.com/pointfreeco/swift-custom-dump", from: "1.7.3"),
        // The `Tagged` trait ships SQLiteData's conformances for `Tagged` IDs.
        .package(url: "https://github.com/pointfreeco/sqlite-data", from: "1.11.2", traits: ["Tagged"]),
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "3.0.1"),
        .package(url: "https://github.com/swiftlang/swift-markdown", from: "0.7.3"),
        .package(url: "https://github.com/appstefan/HighlightSwift", revision: "99c431b38a1444a5fd6a4978307fbbefe3a7af53"),
    ]
)

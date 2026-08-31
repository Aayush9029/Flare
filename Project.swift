import ProjectDescription

private let deploymentTargets: DeploymentTargets = .macOS("26.0")
private let destinations: Destinations = .macOS

let project = Project(
    name: "Flare",
    options: .options(
        defaultKnownRegions: ["en"],
        developmentRegion: "en"
    ),
    settings: .settings(
        base: [
            "SWIFT_VERSION": "6.0",
            "MARKETING_VERSION": "0.1.0",
            "CURRENT_PROJECT_VERSION": "1",
            "CODE_SIGN_STYLE": "Automatic",
        ]
    ),
    targets: [
        .target(
            name: "Flare",
            destinations: destinations,
            product: .app,
            bundleId: "art.aayush.Flare",
            deploymentTargets: deploymentTargets,
            infoPlist: .file(path: "Flare/Info.plist"),
            buildableFolders: ["Flare/Sources"],
            entitlements: .file(path: "Flare/Flare.entitlements"),
            dependencies: [
                .target(name: "FlareKit"),
                .target(name: "FlareUI"),
            ],
            settings: .settings(
                base: [
                    "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
                    "ENABLE_HARDENED_RUNTIME": "YES",
                    "LD_RUNPATH_SEARCH_PATHS": "$(inherited) @executable_path/../Frameworks",
                    "INFOPLIST_KEY_LSApplicationCategoryType": "public.app-category.productivity",
                ]
            )
        ),
        .target(
            name: "FlareKit",
            destinations: destinations,
            product: .staticFramework,
            bundleId: "art.aayush.FlareKit",
            deploymentTargets: deploymentTargets,
            infoPlist: .default,
            buildableFolders: ["FlareKit/Sources"],
            dependencies: [
                .external(name: "Dependencies"),
                .external(name: "DependenciesMacros"),
                .external(name: "Sharing"),
                .external(name: "IdentifiedCollections"),
                .external(name: "CasePaths"),
                .external(name: "SwiftNavigation"),
                .external(name: "Tagged"),
                .external(name: "IssueReporting"),
                .external(name: "SQLiteData"),
                .external(name: "KeyboardShortcuts"),
            ]
        ),
        .target(
            name: "FlareUI",
            destinations: destinations,
            product: .staticFramework,
            bundleId: "art.aayush.FlareUI",
            deploymentTargets: deploymentTargets,
            infoPlist: .default,
            buildableFolders: ["FlareUI/Sources"],
            dependencies: [
                .target(name: "FlareKit"),
                .external(name: "SwiftUINavigation"),
                .external(name: "Sharing"),
                .external(name: "KeyboardShortcuts"),
                .external(name: "SwiftStreamingMarkdown"),
            ]
        ),
        .target(
            name: "FlareKitTests",
            destinations: destinations,
            product: .unitTests,
            bundleId: "art.aayush.FlareKitTests",
            deploymentTargets: deploymentTargets,
            infoPlist: .default,
            buildableFolders: ["FlareKitTests"],
            dependencies: [
                .target(name: "FlareKit"),
                .external(name: "DependenciesTestSupport"),
                .external(name: "CustomDump"),
            ]
        ),
    ]
)

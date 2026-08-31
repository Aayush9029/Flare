import AppKit
import Dependencies
import FlareKit
import SwiftUI

@main
@MainActor
struct FlareApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        guard SingleInstanceLock.shared.acquire() else { exit(0) }
        NSApplication.shared.setActivationPolicy(.accessory)
        prepareDependencies {
            try! $0.bootstrapDatabase()
        }
    }

    /// No window of its own; this scene exists only because `App` requires one.
    var body: some Scene {
        Settings { EmptyView() }
    }
}

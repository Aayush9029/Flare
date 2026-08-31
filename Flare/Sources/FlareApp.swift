import AppKit
import Dependencies
import FlareKit
import SwiftUI

@main
@MainActor
struct FlareApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        guard SingleInstanceLock.acquire() else { exit(0) }
        NSApplication.shared.setActivationPolicy(.accessory)
        prepareDependencies {
            try! $0.bootstrapDatabase()
        }
    }

    var body: some Scene {
        Settings { EmptyView() }
    }
}

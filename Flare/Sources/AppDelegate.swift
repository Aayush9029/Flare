import AppKit
import Dependencies
import FlareKit
import FlareUI
import KeyboardShortcuts
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    @Dependency(\.windowClient) private var windowClient

    private var model: FlareModel?
    private var statusItem: NSStatusItem?
    private var dockObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let model = FlareModel()
        self.model = model

        let content = NSHostingView(
            rootView: PanelContentView(model: model, onOpenSettings: { [weak self] in
                self?.showSettings(model: model)
            })
        )
        content.setFrameSize(NSSize(width: 720, height: 560))
        windowClient.createPanel(content)
        windowClient.setResignHandler { [weak model] in
            guard let model, let id = model.selectedThreadID, !model.isStreaming else { return }
            model.discardEmptyThread(id)
        }

        KeyboardShortcuts.onKeyDown(for: .toggleFlare) { [weak model] in
            Task { @MainActor in model?.toggle() }
        }
        KeyboardShortcuts.onKeyDown(for: .newThread) { [weak model] in
            Task { @MainActor in
                model?.newThread()
                model?.open()
            }
        }

        setUpStatusItem(model: model)
        applyDockPreference(model: model)
    }

    private func setUpStatusItem(model: FlareModel) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(
            systemSymbolName: "bolt.horizontal.fill",
            accessibilityDescription: "Flare"
        )

        let menu = NSMenu()
        menu.addItem(
            withTitle: "Show Flare",
            action: #selector(showPanel),
            keyEquivalent: ""
        ).target = self
        menu.addItem(
            withTitle: "New Chat",
            action: #selector(newChat),
            keyEquivalent: ""
        ).target = self
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "Settings…",
            action: #selector(openSettings),
            keyEquivalent: ","
        ).target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Flare", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        item.menu = menu
        statusItem = item
    }

    /// "Show in Dock" flips the activation policy live.
    private func applyDockPreference(model: FlareModel) {
        withObservationTracking {
            NSApp.setActivationPolicy(model.preferences.showsDockIcon ? .regular : .accessory)
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self, let model = self.model else { return }
                self.applyDockPreference(model: model)
            }
        }
    }

    @objc private func showPanel() {
        model?.open()
    }

    @objc private func newChat() {
        model?.newThread()
        model?.open()
    }

    @objc private func openSettings() {
        guard let model else { return }
        showSettings(model: model)
    }

    private func showSettings(model: FlareModel) {
        windowClient.showSettings(NSHostingView(rootView: SettingsView(model: model)))
    }
}

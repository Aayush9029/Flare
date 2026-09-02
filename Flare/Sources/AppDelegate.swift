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
        // The panel is window-sized. Without this the hosting view re-derives its
        // minimum, maximum and intrinsic sizes on every update, proposing extra
        // widths to every text view and forcing full relayouts at each.
        content.sizingOptions = []
        content.setFrameSize(NSSize(width: 470, height: 660))
        windowClient.createPanel(content)
        windowClient.setCancelHandler { [weak model] in
            guard let model else { return }
            if model.palette.isPresented {
                model.closePalette()
            } else if model.isModelPickerPresented {
                model.dismissModelPicker()
            } else if model.presentedReasoning != nil {
                model.dismissReasoning()
            } else {
                model.hide()
            }
        }
        windowClient.setResignHandler { [weak model] in
            guard let model, let id = model.selectedThreadID, !model.isStreaming else { return }
            model.discardEmptyThread(id)
        }

        KeyboardShortcuts.onKeyDown(for: .toggleFlare) { [weak model] in
            Task { @MainActor in model?.toggle() }
        }

        // The composer's field editor takes Command-V first and drops anything that
        // is not text, so image pastes are caught before dispatch.
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak model] event in
            guard let model, event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
                  event.charactersIgnoringModifiers == "v",
                  event.window is NSPanel
            else { return event }
            let images = ImageDrop.pasteboardImages()
            guard !images.isEmpty else { return event }
            images.forEach(model.addAttachment)
            return nil
        }

        // Without this the licence is only resolved when the License pane appears,
        // so a licensed user is locked out until they open Settings.
        Task { await model.license.start() }

        setUpStatusItem(model: model)
        applyMenuBarPreference(model: model)
        applyDockPreference(model: model)
        applyStaysOnTop(model: model)
        applyRemembersPosition(model: model)
        applyPanelPosition(model: model)
        applyPanelSize(model: model)
        applyPanelWidth(model: model)
    }

    private func setUpStatusItem(model: FlareModel) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = FlareBolt.menuBarImage()
        item.button?.image?.accessibilityDescription = "Flare"

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

    private func applyMenuBarPreference(model: FlareModel) {
        withObservationTracking {
            statusItem?.isVisible = model.preferences.showsMenuBarIcon
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self, let model = self.model else { return }
                self.applyMenuBarPreference(model: model)
            }
        }
    }

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

    private func applyStaysOnTop(model: FlareModel) {
        withObservationTracking {
            windowClient.setStaysOnTop(model.preferences.staysOnTop)
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self, let model = self.model else { return }
                self.applyStaysOnTop(model: model)
            }
        }
    }

    private func applyRemembersPosition(model: FlareModel) {
        withObservationTracking {
            windowClient.setRemembersPosition(model.preferences.remembersPanelPosition)
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self, let model = self.model else { return }
                self.applyRemembersPosition(model: model)
            }
        }
    }

    private func applyPanelPosition(model: FlareModel) {
        withObservationTracking {
            windowClient.setPosition(model.preferences.panelPosition)
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self, let model = self.model else { return }
                self.applyPanelPosition(model: model)
            }
        }
    }

    private func applyPanelSize(model: FlareModel) {
        withObservationTracking {
            windowClient.setSize(model.preferences.panelSize)
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self, let model = self.model else { return }
                self.applyPanelSize(model: model)
            }
        }
    }

    private func applyPanelWidth(model: FlareModel) {
        withObservationTracking {
            windowClient.setWidth(CGFloat(model.preferences.panelWidth))
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self, let model = self.model else { return }
                self.applyPanelWidth(model: model)
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

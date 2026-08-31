import FlareKit
import SwiftUI

public struct PanelContentView: View {
    @Bindable var model: FlareModel
    let onOpenSettings: () -> Void

    public init(model: FlareModel, onOpenSettings: @escaping () -> Void) {
        self.model = model
        self.onOpenSettings = onOpenSettings
    }

    public var body: some View {
        HStack(spacing: 0) {
            if model.isSidebarVisible {
                ThreadSidebar(model: model)
                    .transition(.move(edge: .leading).combined(with: .opacity))
                Divider().opacity(0.5)
            }

            VStack(spacing: 0) {
                toolbar
                Divider().opacity(0.5)
                if let threadID = model.selectedThreadID {
                    MessageListView(threadID: threadID, model: model)
                } else {
                    Spacer()
                }
                ComposerView(model: model)
            }
        }
        .animation(.bouncy(duration: 0.3), value: model.isSidebarVisible)
        .background(hiddenShortcuts)
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            Button {
                model.isSidebarVisible.toggle()
            } label: {
                Image(systemName: "sidebar.leading")
            }
            .buttonStyle(.plain)
            .help("Toggle chat list (⌘L)")

            Text(model.preferences.model.displayName)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            Spacer()

            Button(action: onOpenSettings) {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.plain)
            .help("Settings (⌘,)")

            Button(action: model.hide) {
                Image(systemName: "xmark")
            }
            .buttonStyle(.plain)
            .help("Close (Escape)")
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    /// Key equivalents the panel answers to. Hidden rather than rendered so the
    /// chrome stays clean; a borderless panel has no menu bar to hang them off.
    private var hiddenShortcuts: some View {
        Group {
            Button("Close") { model.hide() }
                .keyboardShortcut(.escape, modifiers: [])
            Button("New Chat") { model.newThread() }
                .keyboardShortcut("n", modifiers: .command)
            Button("Toggle Sidebar") { model.isSidebarVisible.toggle() }
                .keyboardShortcut("l", modifiers: .command)
            Button("Stop") { model.stopStreaming() }
                .keyboardShortcut(".", modifiers: .command)
            Button("Settings") { onOpenSettings() }
                .keyboardShortcut(",", modifiers: .command)
            Button("Quit") { NSApp.terminate(nil) }
                .keyboardShortcut("q", modifiers: .command)
        }
        .opacity(0)
        .frame(width: 0, height: 0)
        .accessibilityHidden(true)
    }
}

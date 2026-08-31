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
        VStack(spacing: 0) {
            if let threadID = model.selectedThreadID {
                MessageListView(threadID: threadID, model: model)
            } else {
                Spacer()
            }
            ComposerView(model: model)
        }
        .background(PanelScrim())
        .overlay(alignment: .top) {
            if model.palette.isPresented {
                CommandPaletteView(model: model)
                    .padding(.top, 60)
                    .transition(.scale(scale: 0.96, anchor: .top).combined(with: .opacity))
            }
        }
        .animation(.bouncy(duration: 0.28), value: model.palette.isPresented)
        .background(hiddenShortcuts)
    }

    private var hiddenShortcuts: some View {
        Group {
            Button("Search") { model.togglePalette() }
                .keyboardShortcut("k", modifiers: .command)
            Button("New Chat") { model.newThread() }
                .keyboardShortcut("n", modifiers: .command)
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

import FlareKit
import SwiftUI

public struct PanelContentView: View {
    @Bindable var model: FlareModel
    let onOpenSettings: () -> Void

    public init(model: FlareModel, onOpenSettings: @escaping () -> Void) {
        self.model = model
        self.onOpenSettings = onOpenSettings
    }

    @State private var isDropTargeted = false
    @State private var composerHeight: CGFloat = 0
    @Namespace private var panelNamespace

    public var body: some View {
        VStack(spacing: 0) {
            if let threadID = model.selectedThreadID {
                MessageListView(threadID: threadID, model: model)
            } else {
                Spacer()
            }
            ComposerView(model: model)
                .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { composerHeight = $0 }
        }
        .overlay(alignment: .bottom) {
            // Queued messages float over the chat rather than pushing it up.
            if !model.queuedForCurrentThread.isEmpty {
                QueueOverlay(model: model, composerHeight: composerHeight)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(Morph.animation, value: model.queuedForCurrentThread.isEmpty)
        .onDrop(of: [.image, .fileURL], isTargeted: $isDropTargeted) { providers in
            ImageDrop.load(providers) { model.addAttachment($0) }
        }
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
                    .foregroundStyle(.secondary)
                    .padding(10)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.15), value: isDropTargeted)
        // Hidden, not removed, while the thoughts fill the panel: the transcript
        // keeps its text views and scroll position for the way back.
        .opacity(model.presentedReasoning == nil ? 1 : 0)
        .allowsHitTesting(model.presentedReasoning == nil)
        .overlay {
            if let message = model.presentedReasoning {
                ThoughtsView(message: message, model: model)
                    .morph(Morph.thoughts(message.id), in: panelNamespace, isSource: true)
                    .transition(.opacity)
            }
        }
        .animation(Morph.animation, value: model.presentedReasoning?.id)
        .overlay {
            if model.isModelPickerPresented {
                // Grows out of the chip's corner and shrinks back into it.
                ModelPickerOverlay(model: model)
                    .transition(
                        .asymmetric(
                            insertion: .scale(scale: 0.55, anchor: .bottomTrailing).combined(with: .opacity),
                            removal: .scale(scale: 0.8, anchor: .bottomTrailing).combined(with: .opacity)
                        )
                    )
            }
        }
        .animation(Morph.animation, value: model.isModelPickerPresented)
        .environment(\.panelNamespace, panelNamespace)
        .background(PanelScrim())
        // The panel has no title bar; any spot that nothing else claims drags it.
        .gesture(WindowDragGesture())
        .overlay(alignment: .top) {
            if model.palette.isPresented {
                CommandPaletteView(model: model)
                    .padding(12)
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

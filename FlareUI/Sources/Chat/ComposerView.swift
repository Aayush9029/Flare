import AppKit
import FlareKit
import SwiftUI

struct ComposerView: View {
    @Bindable var model: FlareModel
    @FocusState private var isFocused: Bool

    private let radius: CGFloat = 22

    var body: some View {
        VStack(spacing: 8) {
            if let errorMessage = model.errorMessage {
                ErrorBanner(message: errorMessage) { model.errorMessage = nil }
            }

            if !model.attachments.isEmpty {
                AttachmentStrip(model: model)
            }

            GlassEffectContainer(spacing: 10) {
                HStack(alignment: .center, spacing: 10) {
                    TextField(
                        model.statusPlaceholder,
                        text: $model.draft,
                        axis: .vertical
                    )
                    .textFieldStyle(.plain)
                    .lineLimit(1...10)
                    .font(.system(size: 15))
                    .frame(minHeight: 30)
                    .focused($isFocused)
                    .onSubmit { model.send() }
                    .onKeyPress(.return, phases: .down) { press in
                        guard press.modifiers.contains(.shift) else { return .ignored }
                        model.draft.append("\n")
                        return .handled
                    }

                    ModelChip(model: model)
                        .frame(height: 30)

                    SendButton(isStreaming: model.isStreaming, canSend: canSend) {
                        // Streaming with text typed, the button queues; empty, it stops.
                        if model.isStreaming, !canSend {
                            model.stopStreaming()
                        } else {
                            model.send()
                        }
                    }
                }
                .padding(.leading, 16)
                .padding(.trailing, 8)
                .padding(.vertical, 6)
                .glassEffect(.regular, in: .rect(cornerRadius: radius))
                .streamingBorder(isActive: model.isStreaming, cornerRadius: radius)
            }
        }
        .padding(16)
        .onPasteCommand(of: [.image, .fileURL]) { providers in
            ImageDrop.load(providers) { model.addAttachment($0) }
        }
        .onAppear { isFocused = true }
        .task(id: model.selectedThreadID) { isFocused = true }
        // Cancelling the palette leaves the thread unchanged, so nothing else
        // would hand first responder back to the field.
        .onChange(of: model.isPalettePresented) { _, shown in
            if !shown { isFocused = true }
        }
        .onChange(of: model.presentedReasoning?.id) { _, shown in
            if shown == nil { isFocused = true }
        }
        .onChange(of: model.isModelPickerPresented) { _, shown in
            if !shown { isFocused = true }
        }
        // Whatever held focus before, the field takes it back when the panel does,
        // so a hotkey or a click on the panel is enough to start typing.
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { note in
            guard note.object is NSPanel else { return }
            isFocused = false
            DispatchQueue.main.async { isFocused = true }
        }
    }

    private var canSend: Bool {
        !model.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !model.attachments.isEmpty
    }
}

private struct ErrorBanner: View {
    let message: String
    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .lineLimit(3)
            Spacer(minLength: 4)
            Button(action: dismiss) {
                Image(systemName: "xmark")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss error")
        }
        .font(.caption)
        .foregroundStyle(.orange)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ModelChip: View {
    let model: FlareModel

    var body: some View {
        Button {
            withAnimation(Morph.animation) { model.toggleModelPicker() }
        } label: {
            HStack(spacing: 4) {
                Text(model.providers.selectionTitle)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .font(.caption.weight(.medium))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Model")
        .accessibilityValue(model.providers.selectionTitle)
        .help("Choose the model and how hard it thinks")
    }
}

private struct SendButton: View {
    let isStreaming: Bool
    let canSend: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isStreaming ? (canSend ? "text.line.first.and.arrowtriangle.forward" : "stop.fill") : "arrow.up")
                .font(.system(size: 12, weight: .bold))
                .frame(width: 24, height: 24)
                .contentTransition(.symbolEffect(.replace))
        }
        .accessibilityLabel(isStreaming ? (canSend ? "Add to queue" : "Stop generating") : "Send message")
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.circle)
        .disabled(!isStreaming && !canSend)
        .help(isStreaming ? (canSend ? "Queue (Return) · Stop (⌘.)" : "Stop (⌘.)") : "Send (Return)")
    }
}

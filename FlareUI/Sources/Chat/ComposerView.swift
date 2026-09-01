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
                    .onSubmit(model.send)
                    .onKeyPress(.return, phases: .down) { press in
                        guard press.modifiers.contains(.shift) else { return .ignored }
                        model.draft.append("\n")
                        return .handled
                    }

                    ModelChip(preferences: model.preferences)
                        .frame(height: 30)

                    SendButton(isStreaming: model.isStreaming, canSend: canSend) {
                        model.isStreaming ? model.stopStreaming() : model.send()
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
        .onAppear { isFocused = true }
        .task(id: model.selectedThreadID) { isFocused = true }
        // Cancelling the palette leaves the thread unchanged, so nothing else
        // would hand first responder back to the field.
        .onChange(of: model.palette.isPresented) { _, shown in
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
        !model.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
    @Bindable var preferences: Preferences

    var body: some View {
        Menu {
            Picker("Model", selection: modelBinding) {
                ForEach(ChatModelCatalog.all) { option in
                    Text(option.displayName).tag(option.id)
                }
            }
            .pickerStyle(.inline)

            Picker("Effort", selection: effortBinding) {
                ForEach(preferences.model.efforts, id: \.self) { effort in
                    Text(effort.capitalized).tag(effort)
                }
            }
            .pickerStyle(.inline)
        } label: {
            HStack(spacing: 4) {
                Text(preferences.model.shortName)
                    .foregroundStyle(.primary)
                Text(preferences.effectiveEffort.capitalized)
                    .foregroundStyle(.secondary)
            }
            .font(.caption.weight(.medium))
        }
        .accessibilityLabel("Model and reasoning effort")
        .accessibilityValue("\(preferences.model.displayName), \(preferences.effectiveEffort)")
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var modelBinding: Binding<String> {
        Binding(
            get: { preferences.selectedModel },
            set: { value in preferences.$selectedModel.withLock { $0 = value } }
        )
    }

    private var effortBinding: Binding<String> {
        Binding(
            get: { preferences.effectiveEffort },
            set: { value in preferences.$reasoningEffort.withLock { $0 = value } }
        )
    }
}

private struct SendButton: View {
    let isStreaming: Bool
    let canSend: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isStreaming ? "stop.fill" : "arrow.up")
                .font(.system(size: 12, weight: .bold))
                .frame(width: 24, height: 24)
        }
        .accessibilityLabel(isStreaming ? "Stop generating" : "Send message")
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.circle)
        .disabled(!isStreaming && !canSend)
        .help(isStreaming ? "Stop (⌘.)" : "Send (Return)")
    }
}

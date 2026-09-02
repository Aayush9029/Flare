import FlareKit
import SwiftUI

/// The chooser in a card over the composer. A click anywhere else, Escape, or three
/// seconds after letting go put it away.
struct ModelPickerOverlay: View {
    let model: FlareModel
    var onOpenSettings: () -> Void = {}

    @Environment(\.colorScheme) private var colorScheme
    @State private var dismissal: Task<Void, Never>?

    var body: some View {
        ZStack(alignment: .bottom) {
            if model.isModelPickerPresented {
                // The band fades in where it is; a material under a gradient mask, clear
                // at the top and frosted where the card sits.
                Rectangle()
                    .fill(.regularMaterial)
                    .mask {
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0),
                                .init(color: .clear, location: 0.25),
                                .init(color: .black, location: 0.7),
                                .init(color: .black, location: 1),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                    .contentShape(.rect)
                    .onTapGesture { withAnimation(Morph.animation) { model.dismissModelPicker() } }
                    .transition(.opacity)

                // The card grows out of the chip's corner and shrinks back into it.
                card
                    .transition(
                        .asymmetric(
                            insertion: .scale(scale: 0.55, anchor: .bottomTrailing).combined(with: .opacity),
                            removal: .scale(scale: 0.85, anchor: .bottomTrailing).combined(with: .opacity)
                        )
                    )
            }
        }
        .animation(Morph.animation, value: model.isModelPickerPresented)
        .onChange(of: model.isModelPickerPresented) { _, presented in
            if !presented { dismissal?.cancel() }
        }
    }

    private var card: some View {
        ModelChooser(providers: model.providers) {
            dismissal?.cancel()
        } onSettle: {
            scheduleDismissal()
        } openSettings: {
            model.dismissModelPicker()
            onOpenSettings()
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .background(cardFill, in: .rect(cornerRadius: 22, style: .continuous))
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.primary.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.35 : 0.12), radius: 18, y: 8)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    /// Soft white in light mode, deep glass in dark.
    private var cardFill: Color {
        colorScheme == .dark ? .black.opacity(0.45) : .white.opacity(0.82)
    }

    private func scheduleDismissal() {
        dismissal?.cancel()
        dismissal = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            withAnimation(Morph.animation) { model.dismissModelPicker() }
        }
    }
}

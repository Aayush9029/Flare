import SwiftUI

/// Grouped form on the window's own material, not the opaque form background, so glass reads through.
struct SettingsForm<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        Form {
            content
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}

/// Stacked bands sharing one clipped, hairline-stroked container.
struct SettingsCard<Content: View>: View {
    @ViewBuilder let content: Content

    private let radius: CGFloat = 16

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .clipShape(.rect(cornerRadius: radius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(.primary.opacity(0.1), lineWidth: 1)
        }
    }
}

extension View {
    /// Depth of a band within a `SettingsCard`. Level 0 is the top band.
    func cardBand(_ level: Int = 0) -> some View {
        modifier(CardBand(level: level))
    }

    func settingFootnote() -> some View {
        font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct CardBand: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let level: Int

    func body(content: Content) -> some View {
        content.background(fill)
    }

    private var fill: Color {
        let dark: [Double] = [0.60, 0.75, 0.90]
        let light: [Double] = [0.06, 0.04, 0.03]
        let index = min(level, dark.count - 1)
        return colorScheme == .dark
            ? .black.opacity(dark[index])
            : .primary.opacity(light[index])
    }
}

struct SelectableCard<Content: View>: View {
    let isSelected: Bool
    var isBlack = false
    let action: () -> Void
    @ViewBuilder let content: Content

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovering = false

    private let radius: CGFloat = 10

    var body: some View {
        Button(action: action) {
            content
                .foregroundStyle(isSelected ? AnyShapeStyle(selectedForeground) : AnyShapeStyle(.primary))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(6)
                .background(cardBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(
                            isSelected ? selectedFill : .primary.opacity(isHovering ? 0.18 : 0.08),
                            lineWidth: isSelected ? 2 : 1
                        )
                }
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }

    private var selectedFill: Color {
        colorScheme == .dark ? .white : .black
    }

    private var selectedForeground: Color {
        colorScheme == .dark ? .black : .white
    }

    @ViewBuilder
    private var cardBackground: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(selectedFill)
        } else if isBlack {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(.black.opacity(colorScheme == .dark ? 0.35 : 0.06))
        } else {
            Color.clear.flareGlass(cornerRadius: radius)
        }
    }
}

struct ToggleCard<Illustration: View>: View {
    let title: String
    let description: String
    let icon: String
    let isOn: Bool
    let action: () -> Void
    @ViewBuilder let illustration: Illustration

    @Environment(\.colorScheme) private var colorScheme
    @State private var isShowingDescription = false
    @State private var isHovering = false

    private let radius: CGFloat = 14

    var body: some View {
        VStack(spacing: 10) {
            Button(action: action) {
                illustration
                    .aspectRatio(2, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .clipShape(.rect(cornerRadius: radius, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(.black.opacity(0.05).shadow(.inner(radius: 10, y: 1)))
                    }
                    .overlay(alignment: .topTrailing) {
                        Image(systemName: icon)
                            .font(.system(size: 15, weight: .bold))
                            .symbolRenderingMode(.hierarchical)
                            .symbolVariant(.fill)
                            .foregroundStyle(isOn ? .primary : .secondary)
                            .padding(10)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(
                                isOn ? (colorScheme == .dark ? .white : .black) : .primary.opacity(0.12),
                                lineWidth: isOn ? 3 : 1
                            )
                    }
                    .overlay(alignment: .topLeading) { infoButton }
                    .shadow(color: .black.opacity(0.25), radius: isHovering ? 9 : 5, y: isHovering ? 5 : 3)
            }
            .buttonStyle(.plain)

            Text(title)
                .font(.callout.weight(.medium))
                .foregroundStyle(isOn ? .primary : .secondary)
        }
        .animation(.easeInOut(duration: 0.25), value: isOn)
        .animation(.easeOut(duration: 0.15), value: isHovering)
        .onHover { isHovering = $0 }
        .popover(isPresented: $isShowingDescription, arrowEdge: .bottom) {
            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(10)
        }
    }

    private var infoButton: some View {
        Image(systemName: "info.circle")
            .font(.system(size: 14, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(.secondary)
            .padding(10)
            .onHover { isShowingDescription = $0 }
    }
}

/// Stand-in for Breeze's animated GIF illustrations.
struct SettingsIllustration: View {
    let symbol: String
    let tint: Color

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [tint.opacity(0.55), tint.opacity(0.15)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: symbol)
                .font(.system(size: 34, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white)
        }
    }
}

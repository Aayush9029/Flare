import FlareKit
import SwiftUI

/// Messages waiting their turn behind the reply that is streaming. Each can be
/// taken back out; the first goes as soon as the reply lands.
struct QueueView: View {
    let model: FlareModel

    var body: some View {
        let queued = model.queuedForCurrentThread
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "text.line.first.and.arrowtriangle.forward")
                    .font(.system(size: 10, weight: .semibold))
                Text(queued.count == 1 ? "1 queued" : "\(queued.count) queued")
                    .font(.caption.weight(.medium))
                Spacer()
                if !model.isStreaming {
                    Button("Send Next") { model.sendNextQueued() }
                        .buttonStyle(.plain)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(QueuePurple.color)
                }
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)

            ForEach(Array(queued.enumerated()), id: \.element.id) { index, item in
                QueueRow(index: index + 1, item: item, isNext: index == 0 && model.isStreaming) {
                    model.removeFromQueue(item.id)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy(duration: 0.25), value: queued.map(\.id))
    }
}

private struct QueueRow: View {
    let index: Int
    let item: QueuedMessage
    let isNext: Bool
    let remove: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            OrbBadge(number: index, isLit: isNext)
            VStack(alignment: .leading, spacing: 2) {
                if !item.text.isEmpty {
                    Text(item.text)
                        .font(.callout)
                        .lineLimit(2)
                }
                if !item.attachments.isEmpty {
                    Label(item.attachments.count == 1 ? "1 image" : "\(item.attachments.count) images", systemImage: "photo")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            Button(action: remove) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .opacity(isHovering ? 1 : 0.45)
            .accessibilityLabel("Remove from queue")
            .help("Remove from queue")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.primary.opacity(0.05), in: .rect(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isNext ? AnyShapeStyle(QueuePurple.color.opacity(0.55)) : AnyShapeStyle(.primary.opacity(0.08)), lineWidth: 1)
        }
        .onHover { isHovering = $0 }
    }
}

/// The picker's purple, so the queue reads as the same family.
enum QueuePurple {
    static let color = Color(red: 0.46, green: 0.26, blue: 0.92)
}

/// A numbered orb: a sphere shaded from the upper left, a dark rim on the far side,
/// a specular glint, and a thread of rim light along the bottom. No drop shadow.
private struct OrbBadge: View {
    let number: Int
    let isLit: Bool

    @Environment(\.colorScheme) private var colorScheme

    private let size: CGFloat = 24

    private var base: [Color] {
        if isLit {
            return [Color(red: 0.86, green: 0.76, blue: 1.0), Color(red: 0.55, green: 0.36, blue: 0.96), Color(red: 0.30, green: 0.14, blue: 0.62)]
        }
        return colorScheme == .dark
            ? [Color(white: 0.72), Color(white: 0.42), Color(white: 0.18)]
            : [Color(white: 0.98), Color(white: 0.78), Color(white: 0.52)]
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: base,
                        center: UnitPoint(x: 0.34, y: 0.28),
                        startRadius: 0,
                        endRadius: size * 0.78
                    )
                )
            // The far side falls into shade: a soft dark band inside the rim.
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [.clear, .clear, .black.opacity(isLit ? 0.42 : 0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: size * 0.3
                )
                .blur(radius: 1.8)
                .mask(Circle())
            // The glint where the light lands.
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.95), .white.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size * 0.5, height: size * 0.3)
                .offset(x: -size * 0.08, y: -size * 0.28)
                .blur(radius: 0.5)
            // Light bouncing back up from below.
            Circle()
                .strokeBorder(.white.opacity(isLit ? 0.5 : 0.35), lineWidth: 1)
                .mask {
                    LinearGradient(colors: [.clear, .clear, .white], startPoint: .top, endPoint: .bottom)
                }
                .padding(1)
            Text("\(number)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(isLit ? .white : (colorScheme == .dark ? .white.opacity(0.9) : .black.opacity(0.65)))
        }
        .frame(width: size, height: size)
        .shimmer(isActive: isLit)
        .accessibilityHidden(true)
    }
}

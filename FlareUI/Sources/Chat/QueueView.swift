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

/// A plain numbered circle: purple for the message that goes next, grey for the rest.
private struct OrbBadge: View {
    let number: Int
    let isLit: Bool

    var body: some View {
        Text("\(number)")
            .font(.system(size: 10.5, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(isLit ? .white : .secondary)
            .frame(width: 20, height: 20)
            .background(isLit ? AnyShapeStyle(QueuePurple.color) : AnyShapeStyle(.primary.opacity(0.12)), in: .circle)
            .shimmer(isActive: isLit)
            .accessibilityHidden(true)
    }
}

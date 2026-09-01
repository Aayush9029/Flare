import AppKit
import FlareKit
import SwiftUI

/// Thumbnails of the images waiting to go with the next message.
struct AttachmentStrip: View {
    let model: FlareModel

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(Array(model.attachments.enumerated()), id: \.offset) { index, data in
                    ZStack(alignment: .topTrailing) {
                        if let image = NSImage(data: data) {
                            Image(nsImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 56, height: 56)
                                .clipShape(.rect(cornerRadius: 10, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .strokeBorder(.primary.opacity(0.12), lineWidth: 1)
                                }
                        }
                        Button {
                            model.removeAttachment(at: index)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, .black.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                        .offset(x: 5, y: -5)
                        .accessibilityLabel("Remove image")
                    }
                }
            }
            .padding(.horizontal, 4)
            .padding(.top, 6)
        }
        .scrollIndicators(.hidden)
        .frame(height: 68)
    }
}

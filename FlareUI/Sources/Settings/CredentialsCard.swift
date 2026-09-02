import FlareKit
import SwiftUI

/// The API key for one vendor, after Compose: a masked field with an eye, VERIFY,
/// GET KEY while empty, and a red badge until a key is in.
struct CredentialsCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let provider: ProviderInfo
    @Binding var apiKey: String
    @Binding var showAPIKey: Bool
    let validation: ValidationState
    let hasStoredKey: Bool
    let onVerify: () -> Void
    let onRemove: () -> Void

    @State private var isHoveringSave = false
    @State private var isHoveringGetKey = false
    @FocusState private var isAPIKeyFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Image(systemName: "key.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.orange)
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(provider.name.uppercased()) API KEY")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)

                    Group {
                        if showAPIKey {
                            TextField(provider.kind.keyPlaceholder, text: $apiKey)
                        } else {
                            SecureField(provider.kind.keyPlaceholder, text: $apiKey)
                        }
                    }
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.primary)
                    .disabled(validation == .validating)
                    .focused($isAPIKeyFocused)
                    .onSubmit(onVerify)
                }

                Spacer()

                Button {
                    showAPIKey.toggle()
                } label: {
                    Image(systemName: showAPIKey ? "eye.slash" : "eye")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(.cardTop(colorScheme))
            .onChange(of: apiKey) { _, newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed != newValue { apiKey = trimmed }
            }

            HStack(spacing: 16) {
                buttons
                Spacer()
                feedback
            }
            .padding(16)
            .background(.cardBottom(colorScheme))
        }
        .clipShape(.rect(cornerRadius: 16))
        .overlay {
            let borderColor: Color = if apiKey.isEmpty {
                isAPIKeyFocused ? .blue.opacity(0.8) : .red.opacity(0.6)
            } else {
                .primary.opacity(0.1)
            }
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(borderColor, lineWidth: apiKey.isEmpty ? 2 : 1)
        }
        .overlay(alignment: .topTrailing) {
            if apiKey.isEmpty {
                MissingBadge(text: "API key missing")
            }
        }
        .onTapGesture {
            if apiKey.isEmpty { isAPIKeyFocused = true }
        }
    }

    @ViewBuilder
    private var buttons: some View {
        Button(action: onVerify) {
            Text("VERIFY")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(apiKey.count > 6 ? (isHoveringSave ? .green : .blue) : .clear, in: .rect(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .foregroundStyle(apiKey.count > 6 ? .white : .primary.opacity(0.3))
        .disabled(apiKey.count <= 6 || validation == .validating)
        .onHover { isHoveringSave = $0 }

        if apiKey.isEmpty, let url = provider.kind.signupURL {
            Link(destination: url) {
                Text("GET KEY")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(isHoveringGetKey ? .blue : .secondary)
            .onHover { isHoveringGetKey = $0 }
        } else if hasStoredKey {
            Button("REMOVE", action: onRemove)
                .buttonStyle(.plain)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .disabled(validation == .validating)
        }
    }

    @ViewBuilder
    private var feedback: some View {
        switch validation {
        case .idle:
            Text(provider.name)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
        case .validating:
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text("Validating...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .success:
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Saved")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.green)
            }
        case .failure(let message):
            HStack(spacing: 6) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
                Text(message.isEmpty ? "Invalid" : message)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.red)
                    .lineLimit(1)
            }
        }
    }
}

struct MissingBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                LinearGradient(colors: [.red, .red.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
            )
            .clipShape(.capsule)
            .overlay {
                Capsule()
                    .strokeBorder(.white.opacity(0.5), lineWidth: 1.5)
            }
            .offset(y: -12)
            .padding(.trailing, 16)
    }
}

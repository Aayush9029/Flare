import FlareKit
import SwiftUI

/// A custom endpoint's name, base URL and optional key in the credentials card's
/// clothes. VERIFY saves and lists the server's models.
struct EndpointCredentialsCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let providers: ProviderCatalog
    /// Nil while a new endpoint is being added.
    let provider: ProviderInfo?
    var onSaved: (CustomProvider) -> Void = { _ in }
    var onRemoved: () -> Void = {}

    @State private var name = ""
    @State private var baseURL = ""
    @State private var apiKey = ""
    @State private var showAPIKey = false
    @State private var validation = ValidationState.idle
    @State private var isHoveringSave = false
    @State private var showingRemoveConfirmation = false
    @FocusState private var focusedField: Field?

    private enum Field { case name, url, key }

    private var isNew: Bool { provider == nil }

    private var canVerify: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && CustomProvider.normalize(baseURL) != nil && validation != .validating
    }

    private var liveIcon: String? {
        CustomProvider.normalize(baseURL).flatMap(ProviderIcon.name(for:))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                ProviderGlyph(icon: liveIcon, symbol: "server.rack", size: 24)
                    .foregroundStyle(.orange)
                    .frame(width: 28, height: 28)
                    .animation(.easeInOut(duration: 0.2), value: liveIcon)

                VStack(alignment: .leading, spacing: 10) {
                    field("NAME") {
                        TextField("My server", text: $name)
                            .focused($focusedField, equals: .name)
                    }
                    field("BASE URL") {
                        TextField(String("https://openrouter.ai/api/v1"), text: $baseURL)
                            .font(.system(.body, design: .monospaced))
                            .focused($focusedField, equals: .url)
                    }
                    field("API KEY") {
                        HStack {
                            Group {
                                if showAPIKey {
                                    TextField("Optional", text: $apiKey)
                                } else {
                                    SecureField("Optional", text: $apiKey)
                                }
                            }
                            .font(.system(.body, design: .monospaced))
                            .focused($focusedField, equals: .key)
                            Button {
                                showAPIKey.toggle()
                            } label: {
                                Image(systemName: showAPIKey ? "eye.slash" : "eye")
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    if isNew {
                        HStack(spacing: 6) {
                            ForEach(CustomProvider.presets) { preset in
                                Button(preset.name) {
                                    baseURL = preset.url
                                    if name.isEmpty { name = preset.name }
                                }
                                .buttonStyle(.plain)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(.primary.opacity(0.08), in: .capsule)
                            }
                        }
                    }
                }
            }
            .padding(16)
            .background(.cardTop(colorScheme))

            HStack(spacing: 16) {
                Button(action: save) {
                    Text(isNew ? "ADD" : "VERIFY")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(canVerify ? (isHoveringSave ? .green : .blue) : .clear, in: .rect(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .foregroundStyle(canVerify ? .white : .primary.opacity(0.3))
                .disabled(!canVerify)
                .onHover { isHoveringSave = $0 }

                if !isNew {
                    Button("REMOVE") { showingRemoveConfirmation = true }
                        .buttonStyle(.plain)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .confirmationDialog("Remove \(provider?.name ?? "this endpoint")?", isPresented: $showingRemoveConfirmation) {
                            Button("Remove", role: .destructive) {
                                guard let provider, let id = UUID(uuidString: provider.id) else { return }
                                do {
                                    try providers.removeCustom(id)
                                    onRemoved()
                                } catch {
                                    validation = .failure(error.localizedDescription)
                                }
                            }
                            Button("Cancel", role: .cancel) {}
                        } message: {
                            Text("Its key is deleted from this Mac. Your chats stay.")
                        }
                }
                Spacer()
                feedback
            }
            .padding(16)
            .background(.cardBottom(colorScheme))
        }
        .clipShape(.rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(isNew ? Color.blue.opacity(0.8) : Color.primary.opacity(0.1), lineWidth: isNew ? 2 : 1)
        }
        .onAppear { load() }
        .onChange(of: provider?.id) { _, _ in load() }
    }

    private func field(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
            content()
                .textFieldStyle(.plain)
                .foregroundStyle(.primary)
                .disabled(validation == .validating)
        }
    }

    @ViewBuilder
    private var feedback: some View {
        switch validation {
        case .idle:
            if let provider {
                let count = provider.models.count
                Text(count == 0 ? "No models listed" : "\(count) model\(count == 1 ? "" : "s")")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(count == 0 ? .orange : .primary)
            } else {
                Text("New endpoint")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
            }
        case .validating:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Listing models...")
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
                Text(message)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.red)
                    .lineLimit(1)
            }
        }
    }

    private func load() {
        validation = .idle
        guard let provider, let custom = providers.custom(provider.id) else {
            name = ""
            baseURL = ""
            apiKey = ""
            return
        }
        name = custom.name
        baseURL = custom.baseURL.absoluteString
        apiKey = providers.key(for: provider) ?? ""
    }

    /// Saves the endpoint as typed, then lists its models with the key. A server
    /// that lists nothing still saves; the picker takes a typed id.
    private func save() {
        guard let url = CustomProvider.normalize(baseURL) else { return }
        let name = name.trimmingCharacters(in: .whitespaces)
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        validation = .validating
        Task {
            do {
                let saved: ProviderInfo
                if let provider, let custom = providers.custom(provider.id) {
                    var updated = custom
                    updated.name = name
                    updated.baseURL = url
                    try providers.updateCustom(updated)
                    saved = providers.provider(provider.id) ?? provider
                } else {
                    let added = try providers.addCustom(name: name, baseURL: url)
                    onSaved(added)
                    saved = providers.provider(added.id.uuidString)!
                }
                try await providers.setKey(key, for: saved)
                validation = .success
                try? await Task.sleep(for: .seconds(2))
                validation = .idle
            } catch {
                validation = .failure(error.localizedDescription)
            }
        }
    }
}

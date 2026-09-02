import FlareKit
import SwiftUI

/// Compose's AI Provider page: the credential for the chosen provider, a grid of
/// providers, then that provider's models. Choosing a provider here makes it answer.
struct ProvidersPane: View {
    let providers: ProviderCatalog

    @State private var selectedID: String
    @State private var isAddingEndpoint = false
    @State private var apiKey = ""
    @State private var showAPIKey = false
    @State private var validation = ValidationState.idle
    @State private var validationTask: Task<Void, Never>?

    init(providers: ProviderCatalog) {
        self.providers = providers
        _selectedID = State(initialValue: providers.preferences.activeProvider)
    }

    private var selected: ProviderInfo {
        providers.provider(selectedID) ?? providers.providers[0]
    }

    private var selection: ModelSelection { providers.selection(for: selected) }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                credentials
                providerGrid
                if !isAddingEndpoint {
                    modelSection
                    reasoningSection
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.horizontal, 12)
            .padding(.top, 20)
            .padding(.bottom, 12)
            .animation(.easeInOut(duration: 0.25), value: isAddingEndpoint)
            .animation(.easeInOut(duration: 0.25), value: selectedID)
        }
        .scrollContentBackground(.hidden)
        .onAppear {
            providers.reload()
            loadKey()
        }
        .onDisappear {
            validationTask?.cancel()
            validationTask = nil
        }
    }

    // MARK: - Credentials

    @ViewBuilder
    private var credentials: some View {
        if isAddingEndpoint {
            EndpointCredentialsCard(providers: providers, provider: nil) { added in
                isAddingEndpoint = false
                select(added.id.uuidString)
            }
        } else {
            switch selected.kind {
            case .chatGPT:
                ChatGPTCredentialsCard(providers: providers)
            case .compatible:
                EndpointCredentialsCard(providers: providers, provider: selected) { _ in } onRemoved: {
                    select(ProviderKind.chatGPT.rawValue)
                }
            default:
                CredentialsCard(
                    provider: selected,
                    apiKey: $apiKey,
                    showAPIKey: $showAPIKey,
                    validation: validation,
                    hasStoredKey: providers.key(for: selected) != nil,
                    onVerify: verifyKey,
                    onRemove: removeKey
                )
            }
        }
    }

    // MARK: - Provider Grid

    private var providerGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(providers.providers) { provider in
                ProviderCard(provider: provider, isSelected: !isAddingEndpoint && selectedID == provider.id)
                    .onTapGesture { select(provider.id) }
            }
            AddEndpointCard(isSelected: isAddingEndpoint)
                .onTapGesture {
                    validationTask?.cancel()
                    validation = .idle
                    isAddingEndpoint = true
                }
        }
    }

    // MARK: - Models

    @ViewBuilder
    private var modelSection: some View {
        if selected.isLongList {
            GroupedModelPicker(providers: providers, provider: selected)
                .id(selected.id)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text("Model")
                    .font(.headline)
                if selected.models.isEmpty {
                    modelsPlaceholder
                } else {
                    modelGrid
                }
            }
        }
    }

    private var modelGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(selected.models) { model in
                ModelCard(
                    model: model,
                    icon: selected.icon,
                    symbol: selected.kind.symbol,
                    isSelected: selection.model == model.id
                ) {
                    providers.select(ModelSelection(model: model.id, effort: selection.effort), for: selected)
                }
            }
        }
    }

    private var modelsPlaceholder: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: selected.usesKey ? "key" : "exclamationmark.triangle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text(selected.usesKey ? "Verify a key to list \(selected.name)'s models." : "Nothing listed yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 24)
    }

    @ViewBuilder
    private var reasoningSection: some View {
        let efforts = selected.efforts(for: selection.model)
        if !efforts.isEmpty, !selection.model.isEmpty {
            ReasoningCard(efforts: efforts, effort: selection.effort) { effort in
                providers.select(ModelSelection(model: selection.model, effort: effort == Effort.none ? nil : effort), for: selected)
            }
        }
    }

    // MARK: - Actions

    private func select(_ id: String) {
        validationTask?.cancel()
        validation = .idle
        isAddingEndpoint = false
        selectedID = id
        providers.activate(id)
        showAPIKey = false
        loadKey()
        // A stored key is checked again on the way in, as Compose does.
        if apiKey.count > 6, providers.key(for: selected) != nil, selected.kind != .openAI {
            verifyKey()
        }
    }

    private func loadKey() {
        apiKey = providers.key(for: selected) ?? ""
    }

    private func verifyKey() {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard key.count > 6 else { return }
        let provider = selected
        validationTask?.cancel()
        validationTask = Task {
            validation = .validating
            do {
                try await providers.setKey(key, for: provider)
                validation = .success
                try? await Task.sleep(for: .seconds(2))
                if validation == .success { validation = .idle }
            } catch is CancellationError {
            } catch {
                validation = .failure(error.localizedDescription)
            }
        }
    }

    private func removeKey() {
        validationTask?.cancel()
        do {
            try providers.clearKey(for: selected)
            apiKey = ""
            validation = .idle
        } catch {
            validation = .failure(error.localizedDescription)
        }
    }
}

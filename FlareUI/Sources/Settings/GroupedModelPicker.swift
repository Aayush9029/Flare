import FlareKit
import SwiftUI

/// A long listing, after Compose's OpenRouter picker: an id typed by hand with
/// verification, a search, and the models grouped by vendor behind chevrons.
struct GroupedModelPicker: View {
    @Environment(\.colorScheme) private var colorScheme

    let providers: ProviderCatalog
    let provider: ProviderInfo

    @State private var searchQuery = ""
    @State private var customModelID = ""
    @State private var modelValidation = ValidationState.idle
    @State private var modelValidationTask: Task<Void, Never>?
    @State private var expandedGroups: Set<String> = []

    private var selectedModelID: String { providers.selection(for: provider).model }

    private var groups: [(key: String, title: String, models: [ModelInfo])] {
        let needle = searchQuery.lowercased()
        var order: [String] = []
        var byKey: [String: [ModelInfo]] = [:]
        for model in provider.models where needle.isEmpty || model.id.lowercased().contains(needle) || model.name.lowercased().contains(needle) {
            if byKey[model.groupKey] == nil { order.append(model.groupKey) }
            byKey[model.groupKey, default: []].append(model)
        }
        return order.sorted().map { (key: $0, title: byKey[$0]!.first!.groupTitle, models: byKey[$0]!) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Model")
                .font(.headline)

            customModelEntry
            searchBar

            if provider.models.isEmpty {
                emptyView
            } else {
                categorizedGrid
            }
        }
        .onAppear { customModelID = selectedModelID }
        .onDisappear {
            modelValidationTask?.cancel()
            modelValidationTask = nil
        }
    }

    private var customModelEntry: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "pencil.line")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text("CUSTOM MODEL")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)

                    TextField("e.g. meta-llama/llama-3.1-70b", text: $customModelID)
                        .textFieldStyle(.plain)
                        .font(.system(.body, design: .monospaced))
                        .onSubmit(verifyTyped)
                }

                Spacer()

                verifyModelButton
            }
            .padding(12)
            .background(.cardTop(colorScheme))

            HStack {
                modelValidationFeedback
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.cardBottom(colorScheme))
        }
        .clipShape(.rect(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.primary.opacity(0.1), lineWidth: 1)
        }
    }

    @ViewBuilder
    private var verifyModelButton: some View {
        let canVerify = !customModelID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && modelValidation != .validating

        Button(action: verifyTyped) {
            Text("VERIFY")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(canVerify ? .blue : .clear, in: .rect(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .foregroundStyle(canVerify ? .white : .primary.opacity(0.3))
        .disabled(!canVerify)
    }

    @ViewBuilder
    private var modelValidationFeedback: some View {
        switch modelValidation {
        case .idle:
            Text("Enter a model ID to verify")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .validating:
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text("Sending 2+2...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .success:
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Model verified")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.green)
            }
        case .failure(let message):
            HStack(spacing: 6) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(1)
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search models...", text: $searchQuery)
                .textFieldStyle(.plain)
        }
        .padding(8)
        .background(.cardTop(colorScheme))
        .clipShape(.rect(cornerRadius: 8))
    }

    private var categorizedGrid: some View {
        LazyVStack(alignment: .leading, spacing: 8) {
            ForEach(groups, id: \.key) { group in
                groupSection(group.key, title: group.title, models: group.models)
            }
        }
    }

    @ViewBuilder
    private func groupSection(_ key: String, title: String, models: [ModelInfo]) -> some View {
        let isExpanded = expandedGroups.contains(key) || !searchQuery.isEmpty

        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if expandedGroups.contains(key) {
                        expandedGroups.remove(key)
                    } else {
                        expandedGroups.insert(key)
                    }
                }
            } label: {
                HStack {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 16)

                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text("\(models.count)")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.primary.opacity(0.08), in: .capsule)

                    Spacer()
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(models) { model in
                        CompactModelCard(model: model, isSelected: selectedModelID == model.id) {
                            customModelID = model.id
                            choose(model.id)
                        }
                    }
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 8)
            }
        }
        .background(colorScheme == .dark ? .black.opacity(0.4) : .primary.opacity(0.02))
        .clipShape(.rect(cornerRadius: 10))
    }

    private var emptyView: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text("Could not load models. Use custom entry above.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 24)
    }

    private func verifyTyped() {
        let trimmed = customModelID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        choose(trimmed)
    }

    /// Selects the model, then proves it with a sum as Compose does.
    private func choose(_ id: String) {
        let effort = providers.selection(for: provider).effort
        providers.select(ModelSelection(model: id, effort: effort), for: provider)
        modelValidationTask?.cancel()
        modelValidationTask = Task {
            modelValidation = .validating
            do {
                try await providers.verifyModel(id, for: provider)
                modelValidation = .success
                try? await Task.sleep(for: .seconds(2))
                if modelValidation == .success { modelValidation = .idle }
            } catch is CancellationError {
            } catch {
                modelValidation = .failure(error.localizedDescription)
            }
        }
    }
}

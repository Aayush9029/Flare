import FlareKit
import Sharing
import SwiftUI

struct ModelPane: View {
    @Bindable var preferences: Preferences

    var body: some View {
        SettingsForm {
            Section {
                HStack(spacing: 8) {
                    ForEach(ChatModelCatalog.all) { option in
                        SelectableCard(isSelected: option.id == preferences.selectedModel) {
                            preferences.$selectedModel.withLock { $0 = option.id }
                        } content: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.shortName)
                                    .font(.callout.weight(.medium))
                                Text(option.detail)
                                    .font(.caption)
                                    .opacity(option.id == preferences.selectedModel ? 0.75 : 1)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                        }
                    }
                }
                .padding(.vertical, 2)
            } header: {
                HStack {
                    Text("Model")
                    Spacer()
                    Text(preferences.model.displayName)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Reasoning Effort") {
                HStack(spacing: 8) {
                    ForEach(preferences.model.efforts, id: \.self) { effort in
                        SelectableCard(isSelected: effort == preferences.effectiveEffort, isBlack: true) {
                            preferences.$reasoningEffort.withLock { $0 = effort }
                        } content: {
                            Text(effort.capitalized)
                                .font(.callout)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 2)
                        }
                    }
                }
                Text("Higher effort means slower, more considered answers. Flare clamps this to what the selected model supports.")
                    .settingFootnote()
            }

            Section("System Prompt") {
                TextEditor(text: Binding(preferences.$systemPrompt))
                    .font(.system(.caption, design: .monospaced))
                    .frame(minHeight: 120)
                    .scrollContentBackground(.hidden)
                    .padding(6)
                    .background(.black.opacity(0.15), in: .rect(cornerRadius: 8, style: .continuous))

                Button("Restore Default") {
                    preferences.$systemPrompt.withLock { $0 = Preferences.defaultSystemPrompt }
                }
                .disabled(preferences.systemPrompt == Preferences.defaultSystemPrompt)
            }
        }
    }
}

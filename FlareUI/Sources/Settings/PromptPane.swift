import FlareKit
import Sharing
import SwiftUI

struct PromptPane: View {
    @Bindable var preferences: Preferences

    var body: some View {
        SettingsForm {
            Section("System Prompt") {
                TextEditor(text: Binding(preferences.$systemPrompt))
                    .font(.system(.caption, design: .monospaced))
                    .frame(minHeight: 160)
                    .scrollContentBackground(.hidden)
                    .padding(6)
                    .background(.black.opacity(0.15), in: .rect(cornerRadius: 8, style: .continuous))

                Button("Restore Default") {
                    preferences.$systemPrompt.withLock { $0 = Preferences.defaultSystemPrompt }
                }
                .disabled(preferences.systemPrompt == Preferences.defaultSystemPrompt)

                Text("Sent with every message. The web search guidance is added on top when the tool is on.")
                    .settingFootnote()
            }
        }
    }
}

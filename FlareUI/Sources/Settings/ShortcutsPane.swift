import FlareKit
import KeyboardShortcuts
import SwiftUI

struct ShortcutsPane: View {
    var body: some View {
        SettingsForm {
            Section("Global") {
                KeyboardShortcuts.Recorder("Show Flare", name: .toggleFlare)
                KeyboardShortcuts.Recorder("New Chat", name: .newThread)
            }

            Section("In the Panel") {
                LabeledContent("Send", value: "Return")
                LabeledContent("New line", value: "⇧ Return")
                LabeledContent("New chat", value: "⌘ N")
                LabeledContent("Toggle chat list", value: "⌘ L")
                LabeledContent("Stop streaming", value: "⌘ .")
                LabeledContent("Settings", value: "⌘ ,")
                LabeledContent("Close panel", value: "Escape")
            }
        }
    }
}

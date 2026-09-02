import FlareKit
import KeyboardShortcuts
import SwiftUI

struct ShortcutsPane: View {
    var body: some View {
        SettingsForm {
            Section("Global") {
                KeyboardShortcuts.Recorder("Show Flare", name: .toggleFlare)
                KeyboardShortcuts.Recorder("Capture to chat", name: .captureToChat)
                Text("Capture opens the screenshot crosshair. The area you pick lands in the composer, ready for a question.")
                    .settingFootnote()
            }

            Section("In the Panel") {
                LabeledContent("Send", value: "Return")
                LabeledContent("New line", value: "⇧ Return")
                LabeledContent("New chat", value: "⌘ N")
                LabeledContent("Search chats", value: "⌘ K")
                LabeledContent("Stop streaming", value: "⌘ .")
                LabeledContent("Settings", value: "⌘ ,")
                LabeledContent("Close panel", value: "Escape")
            }
        }
    }
}

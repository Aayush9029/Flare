import FlareKit
import Sharing
import SwiftUI

struct GeneralPane: View {
    @Bindable var preferences: Preferences
    @State private var launchAtLogin = LaunchAtLogin()

    var body: some View {
        SettingsForm {
            Section {
                HStack(alignment: .top, spacing: 20) {
                    ToggleCard(
                        title: "Open at Login",
                        description: "Flare is ready the moment you log in.",
                        icon: "power",
                        isOn: launchAtLogin.isEnabled,
                        action: { launchAtLogin.set(!launchAtLogin.isEnabled) }
                    ) {
                        SettingsIllustration(symbol: "power", tint: .green)
                    }

                    ToggleCard(
                        title: "Show in Dock",
                        description: "Adds a Dock tile and an app switcher entry.",
                        icon: "dock.rectangle",
                        isOn: preferences.showsDockIcon,
                        action: { preferences.$showsDockIcon.withLock { $0.toggle() } }
                    ) {
                        SettingsIllustration(symbol: "dock.rectangle", tint: .blue)
                    }
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 6)
                .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))

                if let failureMessage = launchAtLogin.failureMessage {
                    Label(failureMessage, systemImage: "exclamationmark.triangle.fill")
                        .settingFootnote()
                        .foregroundStyle(.orange)
                }
            }

            Section("Panel") {
                Toggle("Start a new chat each time the panel opens", isOn: Binding(preferences.$newThreadOnOpen))
                Toggle("Show the model's reasoning summary", isOn: Binding(preferences.$showsReasoning))
            }
        }
        .task { launchAtLogin.refresh() }
    }
}

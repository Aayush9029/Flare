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
                        AnimatedImage(resource: SettingsIllustration.launchAtLogin)
                    }

                    ToggleCard(
                        title: "Show in Dock",
                        description: "Adds a Dock tile and an app switcher entry.",
                        icon: "dock.rectangle",
                        isOn: preferences.showsDockIcon,
                        action: { preferences.$showsDockIcon.withLock { $0.toggle() } }
                    ) {
                        AnimatedImage(resource: SettingsIllustration.dockIcon)
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

            Section("Position") {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(PanelPosition.allCases) { position in
                        ToggleCard(
                            title: position.title,
                            description: position.description,
                            icon: position.symbol,
                            isOn: preferences.panelPosition == position,
                            action: { preferences.$panelPositionRaw.withLock { $0 = position.rawValue } }
                        ) {
                            PanelPositionIllustration(position: position)
                        }
                    }
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 6)
                .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))

                Toggle("Restore last position", isOn: Binding(preferences.$remembersPanelPosition))
                Text("Drag the panel anywhere and it reopens where you left it. Off, it opens at the spot above every time.")
                    .settingFootnote()
            }

            Section("Panel") {
                Toggle("Search the web when it helps", isOn: Binding(preferences.$webSearchEnabled))
                Toggle("Generate images when asked", isOn: Binding(preferences.$imagesEnabled))
                Toggle("Float on top", isOn: Binding(preferences.$staysOnTop))
                Text("Keeps the panel above other windows and stops it closing when it loses focus. Escape and the hotkey still close it.")
                    .settingFootnote()
                Picker("When Flare opens", selection: Binding(preferences.$newThreadOnOpen)) {
                    Text("Resume the last chat").tag(false)
                    Text("Start a new chat").tag(true)
                }
                .pickerStyle(.inline)
                Toggle("Show the model's reasoning summary", isOn: Binding(preferences.$showsReasoning))
            }
        }
        .task { launchAtLogin.refresh() }
    }
}

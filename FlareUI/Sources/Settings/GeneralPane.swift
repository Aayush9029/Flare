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
                        description: "Flare is ready as soon as you log in.",
                        icon: "power",
                        isOn: launchAtLogin.isEnabled,
                        action: { launchAtLogin.set(!launchAtLogin.isEnabled) }
                    ) {
                        AnimatedImage(resource: SettingsIllustration.launchAtLogin)
                    }

                    ToggleCard(
                        title: "Show in Dock",
                        description: "Adds a Dock icon and an app switcher entry.",
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
                            isOn: preferences.panelPosition == position,
                            aspectRatio: 1.45,
                            action: { preferences.$panelPositionRaw.withLock { $0 = position.rawValue } }
                        ) {
                            PanelPositionIllustration(position: position, size: preferences.panelSize)
                        }
                    }
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 6)
                .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))

                Toggle("Restore last position", isOn: Binding(preferences.$remembersPanelPosition))
                Text("Reopens where you dragged it.")
                    .settingFootnote()
            }

            Section("Size") {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(PanelSize.allCases) { size in
                        ToggleCard(
                            title: size.title,
                            description: size.description,
                            isOn: preferences.panelSize == size,
                            aspectRatio: 1.45,
                            action: { preferences.$panelSizeRaw.withLock { $0 = size.rawValue } }
                        ) {
                            PanelPositionIllustration(position: preferences.panelPosition, size: size)
                        }
                    }
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 6)
                .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
            }

            Section("Tools") {
                HStack(spacing: 10) {
                    ToolChip(title: "Web", symbol: "globe", isOn: preferences.webSearchEnabled) {
                        preferences.$webSearchEnabled.withLock { $0.toggle() }
                    }
                    ToolChip(title: "Image", symbol: "photo", isOn: preferences.imagesEnabled) {
                        preferences.$imagesEnabled.withLock { $0.toggle() }
                    }
                    Spacer()
                }
                .padding(.vertical, 4)
                Text("Click to turn a tool on or off. The model reaches for them on its own.")
                    .settingFootnote()
            }

            Section("Panel") {
                Toggle("Float on top", isOn: Binding(preferences.$staysOnTop))
                Text("Stays above other windows and open when it loses focus.")
                    .settingFootnote()
                Picker("When Flare opens", selection: Binding(preferences.$newThreadOnOpen)) {
                    Text("Resume last chat").tag(false)
                    Text("Start a new chat").tag(true)
                }
                .pickerStyle(.inline)
                Toggle("Show reasoning", isOn: Binding(preferences.$showsReasoning))
            }
        }
        .task { launchAtLogin.refresh() }
    }
}

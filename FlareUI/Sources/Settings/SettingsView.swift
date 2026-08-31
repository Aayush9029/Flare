import FlareKit
import SwiftUI

public struct SettingsView: View {
    let model: FlareModel
    @State private var tab: SettingsTab? = .general

    public init(model: FlareModel) {
        self.model = model
    }

    public var body: some View {
        NavigationSplitView {
            List(SettingsTab.allCases, selection: $tab) { tab in
                Label {
                    Text(tab.title)
                } icon: {
                    SettingsTabIcon(tab: tab, isSelected: tab == currentTab)
                }
                .padding(.vertical, 4)
                .tag(tab)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 170, ideal: 180, max: 210)
        } detail: {
            pane
                .navigationTitle("")
                .background {
                    VisualEffectBackground(material: .underWindowBackground)
                        .ignoresSafeArea()
                }
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 660, minHeight: 460)
    }

    private var currentTab: SettingsTab { tab ?? .general }

    @ViewBuilder
    private var pane: some View {
        switch currentTab {
        case .general: GeneralPane(preferences: model.preferences)
        case .account: AccountPane()
        case .model: ModelPane(preferences: model.preferences)
        case .shortcuts: ShortcutsPane()
        case .about: AboutPane()
        }
    }
}

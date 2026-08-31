import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case account
    case model
    case shortcuts
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .account: "Account"
        case .model: "Model"
        case .shortcuts: "Shortcuts"
        case .about: "About"
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .account: "person.crop.circle"
        case .model: "sparkle"
        case .shortcuts: "keyboard"
        case .about: "info.circle"
        }
    }

    var tint: Color {
        switch self {
        case .general: .gray
        case .account: .green
        case .model: .indigo
        case .shortcuts: .orange
        case .about: .blue
        }
    }
}

struct SettingsTabIcon: View {
    let tab: SettingsTab
    var isSelected = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(tab.tint.gradient)
                .opacity(isSelected ? 1 : 0.7)
            Image(systemName: tab.symbol)
                .symbolVariant(.fill)
                .foregroundStyle(.white)
                .font(.headline)
        }
        .frame(width: 24, height: 24)
    }
}

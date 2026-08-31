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

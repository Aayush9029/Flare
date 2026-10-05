import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case providers
    case prompt
    case shortcuts
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .providers: "Providers"
        case .prompt: "Prompt"
        case .shortcuts: "Shortcuts"
        case .about: "About"
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .providers: "cloud"
        case .prompt: "text.quote"
        case .shortcuts: "keyboard"
        case .about: "info.circle"
        }
    }

    var tint: Color {
        switch self {
        case .general: .gray
        case .providers: .green
        case .prompt: .indigo
        case .shortcuts: .orange
        case .about: .blue
        }
    }
}

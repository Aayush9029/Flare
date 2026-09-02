import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case providers
    case license
    case prompt
    case shortcuts
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .providers: "Providers"
        case .license: "License"
        case .prompt: "Prompt"
        case .shortcuts: "Shortcuts"
        case .about: "About"
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .providers: "cloud"
        case .license: "key"
        case .prompt: "text.quote"
        case .shortcuts: "keyboard"
        case .about: "info.circle"
        }
    }

    var tint: Color {
        switch self {
        case .general: .gray
        case .providers: .green
        case .license: .purple
        case .prompt: .indigo
        case .shortcuts: .orange
        case .about: .blue
        }
    }
}

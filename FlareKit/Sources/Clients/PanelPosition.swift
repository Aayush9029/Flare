import Foundation

/// Where the panel opens when it has no remembered frame to go back to.
public enum PanelPosition: String, CaseIterable, Sendable, Identifiable {
    case bottomLeft
    case bottomRight
    case center

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .bottomLeft: "Bottom Left"
        case .bottomRight: "Bottom Right"
        case .center: "Center"
        }
    }

    public var description: String {
        switch self {
        case .bottomLeft: "Opens in the lower left corner of the screen with the pointer."
        case .bottomRight: "Opens in the lower right corner of the screen with the pointer."
        case .center: "Opens in the middle of the screen with the pointer."
        }
    }

    public var symbol: String {
        switch self {
        case .bottomLeft: "arrow.down.left"
        case .bottomRight: "arrow.down.right"
        case .center: "plus"
        }
    }
}

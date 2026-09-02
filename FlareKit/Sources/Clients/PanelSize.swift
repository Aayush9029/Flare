import Foundation

/// How tall the panel opens. Width is left to the user.
public enum PanelSize: String, CaseIterable, Sendable, Identifiable {
    case compact
    case half
    case full

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .compact: "Compact"
        case .half: "Half"
        case .full: "Full"
        }
    }

    public var description: String {
        switch self {
        case .compact: "A short, narrow panel that stays out of the way."
        case .half: "Half the height of the screen, a little wider."
        case .full: "The full height of the screen below the menu bar, wider still."
        }
    }

    public var symbol: String {
        switch self {
        case .compact: "rectangle.compress.vertical"
        case .half: "rectangle.split.1x2"
        case .full: "rectangle.expand.vertical"
        }
    }

    /// Gaps kept clear above and below a full-height panel.
    public static let topGap: CGFloat = 12
    public static let bottomGap: CGFloat = 16

    /// Each step up is taller and a little wider.
    public var width: CGFloat {
        switch self {
        case .compact: 470
        case .half: 540
        case .full: 620
        }
    }

    public func height(in visibleHeight: CGFloat, minimum: CGFloat) -> CGFloat {
        let wanted: CGFloat = switch self {
        case .compact: 660
        case .half: visibleHeight / 2
        case .full: visibleHeight - Self.topGap - Self.bottomGap
        }
        return min(max(wanted, minimum), visibleHeight - Self.topGap - Self.bottomGap)
    }
}

import Foundation

/// The five stops of the model slider, from quickest to most considered. Each
/// pairs a model with an effort, so one slide sets both.
public enum ModelLevel: Int, CaseIterable, Sendable, Identifiable {
    case instant
    case medium
    case high
    case extraHigh
    case pro

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .instant: "Instant"
        case .medium: "Medium"
        case .high: "High"
        case .extraHigh: "Extra High"
        case .pro: "Pro"
        }
    }

    public var model: String {
        switch self {
        case .instant: "gpt-5.6-luna"
        case .medium, .high: "gpt-5.6-terra"
        case .extraHigh, .pro: "gpt-5.6-sol"
        }
    }

    public var effort: String {
        switch self {
        case .instant: "low"
        case .medium: "medium"
        case .high, .extraHigh: "high"
        case .pro: "xhigh"
        }
    }

    public var detail: String {
        switch self {
        case .instant: "Quick answers and lookups."
        case .medium: "The everyday default."
        case .high: "More thought on harder questions."
        case .extraHigh: "The flagship model, thinking hard."
        case .pro: "The flagship model, thinking as long as it takes."
        }
    }

    public static func matching(model: String, effort: String) -> ModelLevel? {
        allCases.first { $0.model == model && $0.effort == effort }
    }
}

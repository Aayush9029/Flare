import Foundation

/// A model and, when the model takes one, a reasoning effort. A nil effort sends
/// no reasoning parameter at all.
public struct ModelSelection: Hashable, Codable, Sendable {
    public var model: String
    public var effort: String?

    public init(model: String, effort: String?) {
        self.model = model
        self.effort = effort
    }

    public init(model: String, storedEffort: String) {
        self.init(model: model, effort: storedEffort == Effort.none ? nil : storedEffort)
    }

    public var storedEffort: String { effort ?? Effort.none }
}

public enum Effort {
    public static let none = "none"
    public static let low = "low"
    public static let medium = "medium"
    public static let high = "high"
    public static let extraHigh = "xhigh"

    /// The stops a model of unknown ability offers, Off first.
    public static let standard = [none, low, medium, high]

    public static func title(_ effort: String?) -> String {
        switch effort {
        case nil, none: "Off"
        case low: "Low"
        case medium: "Medium"
        case high: "High"
        case extraHigh: "Extra High"
        case let other?: other.capitalized
        }
    }
}

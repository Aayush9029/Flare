import Foundation

public struct ChatModelOption: Identifiable, Hashable, Sendable {
    public let id: String
    public let displayName: String
    public let detail: String
    public let efforts: [String]

    public init(id: String, displayName: String, detail: String, efforts: [String]) {
        self.id = id
        self.displayName = displayName
        self.detail = detail
        self.efforts = efforts
    }

    public var shortName: String {
        displayName.replacingOccurrences(of: "GPT-", with: "")
    }
}

public enum ChatModelCatalog {
    public static let all: [ChatModelOption] = [
        ChatModelOption(
            id: "gpt-6-astra",
            displayName: "GPT-6 Astra",
            detail: "Frontier reasoning. Slowest, strongest.",
            efforts: ["low", "medium", "high", "xhigh", "max"]
        ),
        ChatModelOption(
            id: "gpt-6.1-sol",
            displayName: "GPT-6.1 Sol",
            detail: "The latest workhorse. The right default for chat.",
            efforts: ["low", "medium", "high", "xhigh"]
        ),
        ChatModelOption(
            id: "gpt-6-luna",
            displayName: "GPT-6 Luna",
            detail: "Fastest. Short answers and quick lookups.",
            efforts: ["low", "medium", "high"]
        ),
    ]

    public static let `default` = all[1]

    public static let titleModel = all[2]

    /// A retired id resolves to the current model of its tier, so a saved
    /// `gpt-5.6-luna` becomes `gpt-6-luna`; an unknown tier gets the default.
    public static func option(id: String) -> ChatModelOption {
        all.first { $0.id == id } ?? all.first { tier(of: $0.id) == tier(of: id) } ?? `default`
    }

    private static func tier(of id: String) -> Substring {
        id.split(separator: "-").last ?? ""
    }
}

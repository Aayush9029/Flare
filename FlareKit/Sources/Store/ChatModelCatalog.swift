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
            id: "gpt-5.6-sol",
            displayName: "GPT-5.6 Sol",
            detail: "Flagship reasoning. Slowest, strongest.",
            efforts: ["low", "medium", "high", "xhigh"]
        ),
        ChatModelOption(
            id: "gpt-5.6-terra",
            displayName: "GPT-5.6 Terra",
            detail: "Balanced. The right default for chat.",
            efforts: ["low", "medium", "high"]
        ),
        ChatModelOption(
            id: "gpt-5.6-luna",
            displayName: "GPT-5.6 Luna",
            detail: "Fastest. Short answers and quick lookups.",
            efforts: ["low", "medium"]
        ),
    ]

    public static let `default` = all[1]

    public static let titleModel = all[2]

    public static func option(id: String) -> ChatModelOption {
        all.first { $0.id == id } ?? `default`
    }
}

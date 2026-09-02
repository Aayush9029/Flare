import Foundation

/// What a vendor's models take when its listing does not say. Nil means unknown,
/// which the picker shows as a slider that starts at Off.
public enum ProviderHints {
    public static func efforts(host: String?, modelID: String) -> [String]? {
        guard let host = host?.lowercased() else { return nil }
        let id = modelID.lowercased()
        if host.hasSuffix("api.groq.com") {
            return id.contains("gpt-oss") ? [Effort.low, Effort.medium, Effort.high] : []
        }
        if host.hasSuffix("api.x.ai") {
            return id.contains("mini") ? [Effort.low, Effort.high] : []
        }
        if host.hasSuffix("googleapis.com") {
            return id.contains("gemini-2.5") || id.contains("gemini-3") ? [Effort.low, Effort.medium, Effort.high] : []
        }
        if host.hasSuffix("api.mistral.ai") || host.hasSuffix("api.deepseek.com") {
            return []
        }
        return nil
    }
}

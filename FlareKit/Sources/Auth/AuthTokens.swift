import Foundation

public struct AuthTokens: Codable, Equatable, Sendable {
    public var idToken: String
    public var accessToken: String
    public var refreshToken: String
    public var accountId: String?
    public var lastRefresh: Date

    public init(
        idToken: String,
        accessToken: String,
        refreshToken: String,
        accountId: String?,
        lastRefresh: Date = Date()
    ) {
        self.idToken = idToken
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.accountId = accountId
        self.lastRefresh = lastRefresh
    }

    public var needsRefresh: Bool {
        guard let exp = JWT.claims(accessToken)?["exp"] as? Double else { return true }
        return Date().timeIntervalSince1970 > exp - 300
    }

    public var account: Account? {
        guard let claims = JWT.claims(idToken) else { return nil }
        let auth = claims["https://api.openai.com/auth"] as? [String: Any]
        return Account(
            email: claims["email"] as? String,
            name: claims["name"] as? String,
            accountId: auth?["chatgpt_account_id"] as? String,
            planType: auth?["chatgpt_plan_type"] as? String
        )
    }
}

public struct Account: Equatable, Sendable {
    public var email: String?
    public var name: String?
    public var accountId: String?
    public var planType: String?

    public var planDisplayName: String {
        switch planType {
        case "pro": "ChatGPT Pro"
        case "plus": "ChatGPT Plus"
        case "team": "ChatGPT Team"
        case "enterprise": "ChatGPT Enterprise"
        case "free": "ChatGPT Free"
        case let other?: other.capitalized
        case nil: "ChatGPT"
        }
    }
}

public enum JWT {
    public static func claims(_ token: String) -> [String: Any]? {
        let parts = token.split(separator: ".")
        guard parts.count >= 2, let data = Data.fromBase64URL(String(parts[1])) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
}

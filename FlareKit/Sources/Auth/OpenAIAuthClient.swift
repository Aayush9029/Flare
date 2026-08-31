import AppKit
import Dependencies
import DependenciesMacros
import Foundation

/// Constants lifted from the Codex CLI's own sign-in flow.
///
/// The client id and the redirect URI belong to OpenAI's public Codex app
/// registration. Neither is configurable: the authorization server rejects any
/// redirect URI other than the one below.
public enum OpenAIOAuth {
    public static let issuer = URL(string: "https://auth.openai.com")!
    public static let clientId = "app_EMoamEEZ73f0CkXaXp7hrann"
    public static let callbackPort: UInt16 = 1455
    public static let callbackPath = "/auth/callback"
    public static let redirectURI = "http://localhost:\(callbackPort)\(callbackPath)"
    public static let scope = "openid profile email offline_access"

    static var authorizeURL: URL { issuer.appending(path: "oauth/authorize") }
    static var tokenURL: URL { issuer.appending(path: "oauth/token") }
    static var revokeURL: URL { issuer.appending(path: "oauth/revoke") }
}

public enum AuthError: LocalizedError, Equatable {
    case portInUse
    case stateMismatch
    case denied(String)
    case tokenExchangeFailed(String)
    case notSignedIn

    public var errorDescription: String? {
        switch self {
        case .portInUse:
            "Port \(OpenAIOAuth.callbackPort) is busy. Quit the Codex CLI login if it is running, then try again."
        case .stateMismatch:
            "The sign-in response did not match this request. Try again."
        case .denied(let reason):
            "OpenAI declined the sign-in: \(reason)"
        case .tokenExchangeFailed(let reason):
            "Could not complete sign-in: \(reason)"
        case .notSignedIn:
            "Sign in with your ChatGPT account to start a chat."
        }
    }
}

@DependencyClient
public struct OpenAIAuthClient: Sendable {
    /// Opens the browser, serves the loopback callback, and stores the tokens.
    public var signIn: @Sendable () async throws -> AuthTokens
    /// Returns stored tokens, refreshing them first when the access token is stale.
    public var validTokens: @Sendable () async throws -> AuthTokens
    public var currentAccount: @Sendable () -> Account?
    public var isSignedIn: @Sendable () -> Bool = { false }
    public var signOut: @Sendable () async throws -> Void
    /// Adopts the Codex CLI's own credentials from `~/.codex/auth.json`.
    public var importFromCodexCLI: @Sendable () async throws -> AuthTokens
}

extension OpenAIAuthClient: DependencyKey {
    public static var liveValue: Self {
        @Dependency(\.tokenStore) var store

        @Sendable
        func exchange(_ form: [String: String]) async throws -> AuthTokens {
            var request = URLRequest(url: OpenAIOAuth.tokenURL)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.httpBody = Data(
                form.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!)" }
                    .joined(separator: "&")
                    .utf8
            )

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                let body = String(data: data, encoding: .utf8) ?? "unknown error"
                throw AuthError.tokenExchangeFailed(body)
            }
            let payload = try JSONDecoder().decode(TokenResponse.self, from: data)
            let tokens = AuthTokens(
                idToken: payload.id_token,
                accessToken: payload.access_token,
                refreshToken: payload.refresh_token ?? form["refresh_token"] ?? "",
                accountId: JWT.claims(payload.id_token)
                    .flatMap { $0["https://api.openai.com/auth"] as? [String: Any] }
                    .flatMap { $0["chatgpt_account_id"] as? String }
            )
            try store.save(tokens)
            return tokens
        }

        return Self(
            signIn: {
                let pkce = PKCE()
                let state = PKCE.randomState()
                let server = LoopbackServer(port: OpenAIOAuth.callbackPort)

                var components = URLComponents(url: OpenAIOAuth.authorizeURL, resolvingAgainstBaseURL: false)!
                components.queryItems = [
                    .init(name: "response_type", value: "code"),
                    .init(name: "client_id", value: OpenAIOAuth.clientId),
                    .init(name: "redirect_uri", value: OpenAIOAuth.redirectURI),
                    .init(name: "scope", value: OpenAIOAuth.scope),
                    .init(name: "code_challenge", value: pkce.challenge),
                    .init(name: "code_challenge_method", value: "S256"),
                    .init(name: "id_token_add_organizations", value: "true"),
                    .init(name: "codex_cli_simplified_flow", value: "true"),
                    .init(name: "state", value: state),
                ]

                async let callback = server.awaitCallback(path: OpenAIOAuth.callbackPath)
                // Give the listener a moment to bind before the browser races to it.
                try await Task.sleep(for: .milliseconds(150))
                NSWorkspace.shared.open(components.url!)

                let query: [String: String]
                do {
                    query = try await callback
                } catch is LoopbackServer.PortUnavailable {
                    throw AuthError.portInUse
                }

                if let error = query["error"] {
                    throw AuthError.denied(query["error_description"] ?? error)
                }
                guard query["state"] == state else { throw AuthError.stateMismatch }
                guard let code = query["code"] else { throw AuthError.denied("no authorization code") }

                return try await exchange([
                    "grant_type": "authorization_code",
                    "code": code,
                    "redirect_uri": OpenAIOAuth.redirectURI,
                    "client_id": OpenAIOAuth.clientId,
                    "code_verifier": pkce.verifier,
                ])
            },

            validTokens: {
                guard let tokens = store.load() else { throw AuthError.notSignedIn }
                guard tokens.needsRefresh else { return tokens }
                return try await exchange([
                    "grant_type": "refresh_token",
                    "refresh_token": tokens.refreshToken,
                    "client_id": OpenAIOAuth.clientId,
                    "scope": "openid profile email",
                ])
            },

            currentAccount: { store.load()?.account },
            isSignedIn: { store.load() != nil },

            signOut: {
                if let tokens = store.load() {
                    var request = URLRequest(url: OpenAIOAuth.revokeURL)
                    request.httpMethod = "POST"
                    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
                    request.httpBody = Data("client_id=\(OpenAIOAuth.clientId)&token=\(tokens.refreshToken)".utf8)
                    _ = try? await URLSession.shared.data(for: request)
                }
                try store.clear()
            },

            importFromCodexCLI: {
                let url = URL(fileURLWithPath: NSHomeDirectory()).appending(path: ".codex/auth.json")
                let data = try Data(contentsOf: url)
                let file = try JSONDecoder().decode(CodexAuthFile.self, from: data)
                let tokens = AuthTokens(
                    idToken: file.tokens.id_token,
                    accessToken: file.tokens.access_token,
                    refreshToken: file.tokens.refresh_token,
                    accountId: file.tokens.account_id
                )
                try store.save(tokens)
                return tokens
            }
        )
    }
}

extension OpenAIAuthClient: TestDependencyKey {
    public static let testValue = Self()
}

public extension DependencyValues {
    var openAIAuth: OpenAIAuthClient {
        get { self[OpenAIAuthClient.self] }
        set { self[OpenAIAuthClient.self] = newValue }
    }
}

private struct TokenResponse: Decodable {
    let id_token: String
    let access_token: String
    let refresh_token: String?
}

private struct CodexAuthFile: Decodable {
    struct Tokens: Decodable {
        let id_token: String
        let access_token: String
        let refresh_token: String
        let account_id: String?
    }
    let tokens: Tokens
}

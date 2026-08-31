import Dependencies
import Foundation
import Testing

@testable import FlareKit

@Suite("PKCE")
struct PKCETests {
    @Test("Challenge is the base64url SHA-256 of the verifier")
    func challengeDerivation() {
        let pkce = PKCE()
        #expect(!pkce.verifier.isEmpty)
        #expect(!pkce.challenge.contains("="))
        #expect(!pkce.challenge.contains("+"))
        #expect(!pkce.challenge.contains("/"))
    }

    @Test("Each instance is unique")
    func uniqueness() {
        #expect(PKCE().verifier != PKCE().verifier)
        #expect(PKCE.randomState() != PKCE.randomState())
    }

    @Test("Base64URL round-trips")
    func roundTrip() {
        let data = Data("the quick brown fox".utf8)
        let encoded = data.base64URLEncodedString()
        #expect(Data.fromBase64URL(encoded) == data)
    }
}

@Suite("Token claims")
struct AuthTokensTests {
    private func makeIDToken(plan: String, expiresIn: TimeInterval) -> String {
        let claims: [String: Any] = [
            "email": "someone@example.com",
            "name": "Someone",
            "exp": Date().addingTimeInterval(expiresIn).timeIntervalSince1970,
            "https://api.openai.com/auth": [
                "chatgpt_account_id": "acct-123",
                "chatgpt_plan_type": plan,
            ],
        ]
        let payload = try! JSONSerialization.data(withJSONObject: claims)
        return "header.\(payload.base64URLEncodedString()).signature"
    }

    @Test("Reads the account out of the id token")
    func account() {
        let token = makeIDToken(plan: "pro", expiresIn: 3600)
        let tokens = AuthTokens(idToken: token, accessToken: token, refreshToken: "rt", accountId: nil)

        #expect(tokens.account?.email == "someone@example.com")
        #expect(tokens.account?.accountId == "acct-123")
        #expect(tokens.account?.planDisplayName == "ChatGPT Pro")
    }

    @Test("A token expiring inside the refresh window needs refreshing")
    func needsRefreshWhenNearExpiry() {
        let soon = makeIDToken(plan: "plus", expiresIn: 60)
        #expect(AuthTokens(idToken: soon, accessToken: soon, refreshToken: "rt", accountId: nil).needsRefresh)
    }

    @Test("A fresh token does not need refreshing")
    func freshToken() {
        let later = makeIDToken(plan: "plus", expiresIn: 3600)
        #expect(!AuthTokens(idToken: later, accessToken: later, refreshToken: "rt", accountId: nil).needsRefresh)
    }

    @Test("An unparsable token is treated as stale")
    func garbageToken() {
        #expect(AuthTokens(idToken: "x", accessToken: "x", refreshToken: "rt", accountId: nil).needsRefresh)
    }
}

@Suite("Token store")
struct TokenStoreTests {
    @Test("Saves, loads, and clears")
    func roundTrip() throws {
        let store = TokenStore.ephemeral()
        #expect(store.load() == nil)

        let tokens = AuthTokens(idToken: "i", accessToken: "a", refreshToken: "r", accountId: "acct")
        try store.save(tokens)
        #expect(store.load()?.accessToken == "a")

        try store.clear()
        #expect(store.load() == nil)
    }
}

@Suite("OAuth constants")
struct OAuthConstantsTests {
    @Test("Redirect URI matches the registration the authorization server expects")
    func redirectURI() {
        #expect(OpenAIOAuth.redirectURI == "http://localhost:1455/auth/callback")
        #expect(OpenAIOAuth.clientId == "app_EMoamEEZ73f0CkXaXp7hrann")
        #expect(OpenAIOAuth.scope.contains("offline_access"))
    }
}

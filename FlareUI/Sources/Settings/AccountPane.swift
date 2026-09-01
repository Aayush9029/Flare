import AppKit
import Dependencies
import FlareKit
import Sharing
import SwiftUI

struct AccountPane: View {
    @Dependency(\.openAIAuth) private var auth
    @Shared(.credentialPreference) private var credentialPreferenceRaw

    @State private var account: Account?
    @State private var apiKey: String?
    @State private var draftKey = ""
    @State private var isEditingKey = false
    @State private var isVerified = false
    @State private var isWorking = false
    @State private var lastErrorMessage: String?
    @State private var showingSignOutConfirmation = false

    private var isSignedIn: Bool { account != nil }

    private var hasCodexSession: Bool {
        FileManager.default.fileExists(atPath: NSHomeDirectory() + "/.codex/auth.json")
    }

    /// The stored choice, with the old Automatic value read as whichever is set up.
    private var choice: CredentialPreference {
        switch CredentialPreference(rawValue: credentialPreferenceRaw) ?? .automatic {
        case .apiKey: .apiKey
        case .chatgpt: .chatgpt
        case .automatic: apiKey == nil ? .chatgpt : .apiKey
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                chooser
                if choice == .apiKey {
                    apiKeyCard
                } else {
                    accountCard
                }

                if let lastErrorMessage {
                    errorRow(lastErrorMessage)
                }

                Text(choice.detail)
                    .font(.callout)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(16)
        }
        .scrollContentBackground(.hidden)
        .task {
            account = auth.currentAccount()
            apiKey = auth.currentAPIKey()
        }
    }

    // MARK: Choice

    private var chooser: some View {
        HStack(spacing: 12) {
            choiceCard(.chatgpt, symbol: "person.crop.circle", caption: isSignedIn ? (account?.email ?? "Signed in") : "Subscription")
            choiceCard(.apiKey, symbol: "key", caption: apiKey == nil ? "Per token" : Self.masked(apiKey ?? ""))
        }
    }

    private func choiceCard(_ option: CredentialPreference, symbol: String, caption: String) -> some View {
        SelectableCard(isSelected: choice == option) {
            choose(option)
        } content: {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.title)
                        .font(.callout.weight(.semibold))
                    Text(caption)
                        .font(.caption)
                        .opacity(0.7)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(8)
        }
    }

    /// ChatGPT adopts a Codex CLI session on its own; the browser is the fallback.
    private func choose(_ option: CredentialPreference) {
        $credentialPreferenceRaw.withLock { $0 = option.rawValue }
        if option == .chatgpt, !isSignedIn, hasCodexSession {
            run { account = try await auth.importFromCodexCLI().account }
        }
    }

    // MARK: ChatGPT

    private var accountCard: some View {
        SettingsCard {
            HStack(spacing: 14) {
                statusIcon
                VStack(alignment: .leading, spacing: 4) {
                    Text("CHATGPT")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text(account?.email ?? "Not signed in")
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                if isWorking {
                    ProgressView().controlSize(.small)
                } else if isSignedIn {
                    statusPill
                }
            }
            .padding(16)
            .cardBand(0)

            HStack(spacing: 16) {
                if isSignedIn {
                    Button("SIGN OUT") { showingSignOutConfirmation = true }
                        .buttonStyle(.plain)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .disabled(isWorking)
                        .confirmationDialog("Sign out of ChatGPT?", isPresented: $showingSignOutConfirmation) {
                            Button("Sign Out", role: .destructive) {
                                run {
                                    try await auth.signOut()
                                    account = nil
                                }
                            }
                            Button("Cancel", role: .cancel) {}
                        } message: {
                            Text("Your chats stay on this Mac.")
                        }
                } else {
                    prominentButton("SIGN IN") {
                        run { account = try await auth.signIn().account }
                    }
                    if hasCodexSession {
                        Button("USE CODEX SESSION") {
                            run { account = try await auth.importFromCodexCLI().account }
                        }
                        .buttonStyle(.plain)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .disabled(isWorking)
                    }
                }
                Spacer()
            }
            .padding(16)
            .cardBand(1)
        }
    }

    // MARK: API key

    private var apiKeyCard: some View {
        SettingsCard {
            HStack(spacing: 14) {
                Image(systemName: apiKey == nil ? "key" : "key.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(apiKey == nil ? AnyShapeStyle(.secondary) : AnyShapeStyle(Color.purple))
                    .frame(width: 36, height: 36)
                VStack(alignment: .leading, spacing: 4) {
                    Text("API KEY")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    if let apiKey, !isEditingKey {
                        // A click on the key opens it for editing.
                        Button {
                            draftKey = apiKey
                            isEditingKey = true
                        } label: {
                            Text(Self.masked(apiKey))
                                .font(.system(.body, design: .monospaced))
                                .lineLimit(1)
                        }
                        .buttonStyle(.plain)
                        .help("Edit the key")
                    } else {
                        SecureField("sk-…", text: $draftKey)
                            .textFieldStyle(.plain)
                            .font(.system(.body, design: .monospaced))
                            .onSubmit(saveDraft)
                    }
                }
                Spacer(minLength: 8)
                if isWorking {
                    ProgressView().controlSize(.small)
                } else if isVerified {
                    Label("Verified", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                }
            }
            .padding(16)
            .cardBand(0)

            HStack(spacing: 16) {
                if apiKey == nil || isEditingKey {
                    prominentButton("SAVE KEY", action: saveDraft)
                        .disabled(draftKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if isEditingKey {
                        Button("CANCEL") {
                            isEditingKey = false
                            draftKey = ""
                        }
                        .buttonStyle(.plain)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    } else {
                        Button("USE SHELL KEY") {
                            run {
                                let key = try auth.importAPIKeyFromEnvironment()
                                try await auth.verifyAPIKey(key)
                                apiKey = key
                                isVerified = true
                            }
                        }
                        .buttonStyle(.plain)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .disabled(isWorking)
                        .help("Reads OPENAI_API_KEY from your login shell")
                    }
                } else {
                    Button("REMOVE KEY") {
                        run {
                            try auth.clearAPIKey()
                            apiKey = nil
                            isVerified = false
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .disabled(isWorking)
                }
                Spacer()
                Text(isWorking ? "Checking with OpenAI…" : "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .cardBand(1)
        }
    }

    /// Whitespace from a paste is dropped, then the key must answer a "hi" before it is kept.
    private func saveDraft() {
        let key = draftKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        run {
            try await auth.verifyAPIKey(key)
            try auth.setAPIKey(key)
            apiKey = key
            draftKey = ""
            isEditingKey = false
            isVerified = true
        }
    }

    private static func masked(_ key: String) -> String {
        guard key.count > 12 else { return String(repeating: "•", count: key.count) }
        return key.prefix(7) + String(repeating: "•", count: 12) + key.suffix(4)
    }

    // MARK: Pieces

    private func prominentButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.accentColor, in: .rect(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .disabled(isWorking)
    }

    private var statusIcon: some View {
        Group {
            if isSignedIn {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
            } else {
                Image(systemName: "lock.fill")
                    .foregroundStyle(.secondary)
                    .symbolEffect(.pulse, isActive: isWorking)
            }
        }
        .font(.system(size: 30))
        .frame(width: 36, height: 36)
        .contentTransition(.symbolEffect(.replace))
        .animation(.easeInOut(duration: 0.25), value: isSignedIn)
    }

    private var statusPill: some View {
        Text(account?.planDisplayName ?? "Active")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.green)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.green.opacity(0.15), in: .rect(cornerRadius: 4))
    }

    private func errorRow(_ message: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.caption)
                .foregroundStyle(.orange.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    private func run(_ work: @escaping () async throws -> Void) {
        isWorking = true
        lastErrorMessage = nil
        Task {
            do {
                try await work()
            } catch {
                lastErrorMessage = error.localizedDescription
            }
            isWorking = false
        }
    }
}

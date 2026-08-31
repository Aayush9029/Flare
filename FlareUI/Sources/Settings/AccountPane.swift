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
    @State private var isWorking = false
    @State private var lastErrorMessage: String?
    @State private var showingSignOutConfirmation = false

    private var isSignedIn: Bool { account != nil }

    private var hasCodexSession: Bool {
        FileManager.default.fileExists(atPath: NSHomeDirectory() + "/.codex/auth.json")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                sourceCard
                accountCard
                apiKeyCard

                if let lastErrorMessage {
                    errorRow(lastErrorMessage)
                }

                helpText
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

    private var sourceCard: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("ANSWER WITH")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Picker("", selection: Binding($credentialPreferenceRaw)) {
                    ForEach(CredentialPreference.allCases, id: \.rawValue) { option in
                        Text(option.title).tag(option.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                Text(selectedPreference.detail)
                    .settingFootnote()
            }
            .padding(16)
            .cardBand(0)
        }
    }

    private var selectedPreference: CredentialPreference {
        CredentialPreference(rawValue: credentialPreferenceRaw) ?? .automatic
    }

    private var accountCard: some View {
        SettingsCard {
            HStack(spacing: 14) {
                statusIcon
                identitySection
                Spacer(minLength: 8)
                trailingControl
            }
            .padding(16)
            .cardBand(0)

            if isSignedIn {
                HStack(spacing: 8) {
                    Text("Subscription")
                        .font(.caption.weight(.medium))
                    statusPill
                    Spacer()
                    actionButtons
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .cardBand(1)
            } else {
                HStack(spacing: 16) {
                    actionButtons
                    Spacer()
                }
                .padding(16)
                .cardBand(1)
            }
        }
    }

    private var apiKeyCard: some View {
        SettingsCard {
            HStack(spacing: 14) {
                Image(systemName: apiKey == nil ? "key" : "key.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(apiKey == nil ? AnyShapeStyle(.secondary) : AnyShapeStyle(Color.purple))
                    .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 4) {
                    Text("OPENAI API KEY")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text(apiKey.map(Self.masked) ?? "Not set")
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
            }
            .padding(16)
            .cardBand(0)

            HStack(spacing: 16) {
                if apiKey == nil {
                    Button("USE ENVIRONMENT KEY") {
                        run { apiKey = try auth.importAPIKeyFromEnvironment() }
                    }
                    .buttonStyle(.plain)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .disabled(isWorking)
                } else {
                    Button("REMOVE KEY") {
                        run {
                            try auth.clearAPIKey()
                            apiKey = nil
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .disabled(isWorking)
                }
                Spacer()
                Text(apiKey == nil ? "Billed to ChatGPT" : "Billed per token")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .cardBand(1)
        }
    }

    private static func masked(_ key: String) -> String {
        guard key.count > 12 else { return String(repeating: "•", count: key.count) }
        return key.prefix(7) + String(repeating: "•", count: 12) + key.suffix(4)
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

    private var identitySection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("CHATGPT ACCOUNT")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            Text(account?.email ?? "Not signed in")
                .font(.system(.body, design: .monospaced))
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var trailingControl: some View {
        if isWorking {
            ProgressView().controlSize(.small)
        } else if isSignedIn {
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(account?.email ?? "", forType: .string)
            } label: {
                Image(systemName: "document.on.document")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Copy email")
        }
    }

    private var statusPill: some View {
        Text(account?.planDisplayName ?? "Active")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.green)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.green.opacity(0.15), in: .rect(cornerRadius: 4))
    }

    @ViewBuilder
    private var actionButtons: some View {
        if isSignedIn {
            Button("SIGN OUT") { showingSignOutConfirmation = true }
                .buttonStyle(.plain)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .disabled(isWorking)
                .confirmationDialog(
                    "Sign out of ChatGPT?",
                    isPresented: $showingSignOutConfirmation
                ) {
                    Button("Sign Out", role: .destructive) {
                        run {
                            try await auth.signOut()
                            account = nil
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Your chats stay on this Mac. You need to sign in again to send new messages.")
                }
        } else {
            Button {
                run { account = try await auth.signIn().account }
            } label: {
                Text("SIGN IN")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.accentColor, in: .rect(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .disabled(isWorking)

            if hasCodexSession {
                Button("USE CODEX CLI SESSION") {
                    run { account = try await auth.importFromCodexCLI().account }
                }
                .buttonStyle(.plain)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .disabled(isWorking)
            }
        }
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

    private var helpText: some View {
        Text(apiKey != nil
            ? "An API key takes priority and bills per token through api.openai.com. Remove it to fall back to your ChatGPT subscription."
            : isSignedIn
                ? "Flare talks to the Codex backend with your ChatGPT subscription. No API key, no extra billing."
                : "Sign in with the same ChatGPT OAuth client the Codex CLI uses, or set an OPENAI_API_KEY. Credentials are stored under Application Support, not the Keychain.")
            .font(.callout)
            .foregroundStyle(.tertiary)
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

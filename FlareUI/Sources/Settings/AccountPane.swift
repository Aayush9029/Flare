import Dependencies
import FlareKit
import SwiftUI

struct AccountPane: View {
    @Dependency(\.openAIAuth) private var auth

    @State private var account: Account?
    @State private var isWorking = false
    @State private var message: String?
    @State private var isConfirmingSignOut = false

    private var codexCLIExists: Bool {
        FileManager.default.fileExists(atPath: NSHomeDirectory() + "/.codex/auth.json")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                SettingsCard {
                    header.cardBand(0)
                    Divider()
                    actions.cardBand(1)
                }

                if let message {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .settingFootnote()
                        .foregroundStyle(.orange)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Text("Flare signs in with the same ChatGPT OAuth client the Codex CLI uses, so your existing subscription drives the chat. No API key required.")
                    .settingFootnote()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(20)
        }
        .task { account = auth.currentAccount() }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: account == nil ? "person.crop.circle.badge.questionmark" : "checkmark.seal.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background((account == nil ? Color.secondary : .green).gradient, in: .rect(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(account?.email ?? "Not signed in")
                    .font(.callout.weight(.medium))
                Text(account.map(\.planDisplayName) ?? "Sign in with your ChatGPT account to start chatting.")
                    .settingFootnote()
            }
            Spacer(minLength: 0)
        }
        .padding(16)
    }

    @ViewBuilder
    private var actions: some View {
        HStack(spacing: 8) {
            if account == nil {
                Button("Sign in with OpenAI…") { run { account = try await auth.signIn() } }
                    .buttonStyle(.borderedProminent)

                if codexCLIExists {
                    Button("Use Codex CLI Session") {
                        run { account = try await auth.importFromCodexCLI().account }
                    }
                }
            } else {
                Button("Sign Out", role: .destructive) { isConfirmingSignOut = true }
            }

            if isWorking {
                ProgressView().controlSize(.small)
                Text(account == nil ? "Waiting for your browser…" : "Working…")
                    .settingFootnote()
            }
            Spacer(minLength: 0)
        }
        .disabled(isWorking)
        .padding(16)
        .confirmationDialog("Sign out of ChatGPT?", isPresented: $isConfirmingSignOut) {
            Button("Sign Out", role: .destructive) {
                run {
                    try await auth.signOut()
                    account = nil
                }
            }
        } message: {
            Text("Your chats stay on this Mac. You will need to sign in again to send new messages.")
        }
    }

    private func run(_ work: @escaping () async throws -> Void) {
        isWorking = true
        message = nil
        Task {
            do {
                try await work()
            } catch {
                message = error.localizedDescription
            }
            isWorking = false
        }
    }
}

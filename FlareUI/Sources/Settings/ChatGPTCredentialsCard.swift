import Dependencies
import FlareKit
import SwiftUI

/// The ChatGPT sign-in in the credentials card's clothes. A Codex CLI session on disk
/// is adopted on its own; the browser is the fallback.
struct ChatGPTCredentialsCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @Dependency(\.openAIAuth) private var auth

    let providers: ProviderCatalog

    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var showingSignOutConfirmation = false
    @State private var isHoveringSignIn = false

    private var account: Account? { providers.chatGPTAccount }
    private var isSignedIn: Bool { account != nil }

    private var hasCodexSession: Bool {
        FileManager.default.fileExists(atPath: NSHomeDirectory() + "/.codex/auth.json")
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.orange)
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text("CHATGPT ACCOUNT")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text(account?.email ?? "Not signed in")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }

                Spacer()

                if isSignedIn {
                    Text(account?.planDisplayName ?? "Active")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.green)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.15), in: .rect(cornerRadius: 4))
                }
            }
            .padding(16)
            .background(.cardTop(colorScheme))

            HStack(spacing: 16) {
                if isSignedIn {
                    Button("SIGN OUT") { showingSignOutConfirmation = true }
                        .buttonStyle(.plain)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .disabled(isWorking)
                        .confirmationDialog("Sign out of ChatGPT?", isPresented: $showingSignOutConfirmation) {
                            Button("Sign Out", role: .destructive) { run { try await auth.signOut() } }
                            Button("Cancel", role: .cancel) {}
                        } message: {
                            Text("Your chats stay on this Mac.")
                        }
                } else {
                    Button {
                        run { _ = try await auth.signIn() }
                    } label: {
                        Text("SIGN IN")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(isHoveringSignIn ? .green : .blue, in: .rect(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                    .disabled(isWorking)
                    .onHover { isHoveringSignIn = $0 }

                    if hasCodexSession {
                        Button("USE CODEX SESSION", action: adoptCodexSession)
                            .buttonStyle(.plain)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .disabled(isWorking)
                    }
                }
                Spacer()
                feedback
            }
            .padding(16)
            .background(.cardBottom(colorScheme))
        }
        .clipShape(.rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(isSignedIn ? Color.primary.opacity(0.1) : Color.red.opacity(0.6), lineWidth: isSignedIn ? 1 : 2)
        }
        .overlay(alignment: .topTrailing) {
            if !isSignedIn {
                MissingBadge(text: "Not signed in")
            }
        }
        .task {
            if !isSignedIn, hasCodexSession { adoptCodexSession() }
        }
    }

    @ViewBuilder
    private var feedback: some View {
        if isWorking {
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Signing in...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else if let errorMessage {
            HStack(spacing: 6) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
                Text(errorMessage)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.red)
                    .lineLimit(1)
            }
        } else {
            Text("ChatGPT")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
        }
    }

    private func adoptCodexSession() {
        run { _ = try await auth.importFromCodexCLI() }
    }

    private func run(_ work: @escaping () async throws -> Void) {
        isWorking = true
        errorMessage = nil
        Task {
            do {
                try await work()
            } catch {
                errorMessage = error.localizedDescription
            }
            providers.reload()
            isWorking = false
        }
    }
}

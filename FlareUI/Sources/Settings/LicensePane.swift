import FlareKit
import SwiftUI

struct LicensePane: View {
    @Bindable var model: LicenseModel

    @State private var keyField = ""
    @State private var isConfirmingDeactivate = false
    @FocusState private var isKeyFieldFocused: Bool

    private var hasEnteredKey: Bool {
        keyField.trimmingCharacters(in: .whitespacesAndNewlines).count > 6
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                licenseCard

                if let message = model.lastErrorMessage {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .settingFootnote()
                        .foregroundStyle(.orange)
                }

                helpText
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(16)
        }
        .scrollContentBackground(.hidden)
        .task {
            await model.start()
            if !model.isUnlocked { isKeyFieldFocused = true }
        }
    }

    private var licenseCard: some View {
        SettingsCard {
            HStack(spacing: 14) {
                statusIcon
                keySection
                Spacer(minLength: 8)
                if model.isWorking { ProgressView().controlSize(.small) }
            }
            .padding(16)
            .cardBand(0)

            HStack(spacing: 16) {
                actionButtons
                Spacer()
                Text("One-time purchase · up to 3 Macs")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .cardBand(1)
        }
    }

    private var statusIcon: some View {
        Group {
            switch model.status {
            case .licensed:
                Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
            case .grace:
                Image(systemName: "clock.badge.exclamationmark.fill").foregroundStyle(.orange)
            case .unlicensed, .unknown:
                Image(systemName: hasEnteredKey ? "key.horizontal.fill" : "lock.fill")
                    .foregroundStyle(hasEnteredKey ? .purple : .secondary)
            }
        }
        .font(.system(size: 30))
        .frame(width: 36, height: 36)
        .contentTransition(.symbolEffect(.replace))
    }

    @ViewBuilder
    private var keySection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("LICENSE KEY")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            switch model.status {
            case .licensed(let displayKey):
                Text(displayKey ?? "Activated")
                    .font(.system(.body, design: .monospaced))
            case .grace:
                Text("Activated, waiting to re-check")
                    .font(.callout)
            case .unlicensed, .unknown:
                TextField("FLARE-XXXX-XXXX-XXXX", text: $keyField)
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .monospaced))
                    .focused($isKeyFieldFocused)
                    .disabled(model.isWorking)
                    .onSubmit { Task { await model.activate(key: keyField) } }
            }
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        if model.isUnlocked {
            Button("CHECK NOW") { Task { await model.refreshTapped() } }
                .buttonStyle(.plain)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .disabled(model.isWorking)

            Button("DEACTIVATE") { isConfirmingDeactivate = true }
                .buttonStyle(.plain)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .disabled(model.isWorking)
                .confirmationDialog("Deactivate this Mac?", isPresented: $isConfirmingDeactivate) {
                    Button("Deactivate", role: .destructive) { Task { await model.deactivate() } }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This frees the activation so you can use the license on another Mac.")
                }
        } else {
            Button {
                Task { await model.activate(key: keyField) }
            } label: {
                Text("ACTIVATE")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(hasEnteredKey ? Color.accentColor : .clear, in: .rect(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .foregroundStyle(hasEnteredKey ? .white : .primary.opacity(0.3))
            .disabled(!hasEnteredKey || model.isWorking)

            if !hasEnteredKey {
                Button("BUY FLARE — $59.99") { model.buy() }
                    .buttonStyle(.plain)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var helpText: some View {
        Text(model.isUnlocked
            ? "Your key was emailed when you bought Flare. It works on up to three Macs."
            : "Flare is a one-time purchase of $59.99. Your key arrives by email straight after checkout.")
            .font(.callout)
            .foregroundStyle(.tertiary)
    }
}

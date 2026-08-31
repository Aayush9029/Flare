import SwiftUI

struct AboutPane: View {
    private var version: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }

    var body: some View {
        SettingsForm {
            Section {
                HStack(spacing: 14) {
                    Image(systemName: "bolt.horizontal.fill")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                        .background(Color.orange.gradient, in: .rect(cornerRadius: 12, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Flare")
                            .font(.title3.weight(.semibold))
                        Text("Version \(version)")
                            .settingFootnote()
                        Text("A floating quick chat driven by your ChatGPT account.")
                            .settingFootnote()
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 4)
            }

            Section("Storage") {
                LabeledContent("Chats", value: "Stored on this Mac only")
                LabeledContent("Credentials", value: "Keychain")
            }
        }
    }
}

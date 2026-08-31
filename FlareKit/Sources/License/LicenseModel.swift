import AppKit
import Dependencies
import Foundation
import Observation

@MainActor
@Observable
public final class LicenseModel {
    public enum Status: Equatable {
        case unknown
        case licensed(displayKey: String?)
        case unlicensed
        /// Polar was unreachable but a key was activated before, so the app keeps
        /// working. Being offline must not lock someone out of what they bought.
        case grace
    }

    @ObservationIgnored @Dependency(\.licenseClient) private var client
    @ObservationIgnored @Dependency(\.licenseStore) private var store

    public private(set) var status: Status = .unknown
    public private(set) var isWorking = false
    public var lastErrorMessage: String?

    public var isUnlocked: Bool {
        switch status {
        case .licensed, .grace: true
        case .unknown, .unlicensed: false
        }
    }

    public init() {}

    public func start() async {
        #if DEBUG
        // Debug-only escape hatch for capturing screenshots and demo footage.
        // Release builds have no way to reach this.
        if ProcessInfo.processInfo.environment["FLARE_SKIP_LICENSE"] != nil {
            status = .licensed(displayKey: "DEBUG")
            return
        }
        #endif
        guard let key = store.key() else {
            status = .unlicensed
            return
        }
        await refresh(key: key)
    }

    public func activate(key: String) async {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !trimmed.isEmpty else { return }
        isWorking = true
        lastErrorMessage = nil
        do {
            let license = try await client.activate(trimmed, Self.machineLabel)
            try store.save(trimmed, license.activation?.id)
            status = license.isValid ? .licensed(displayKey: license.displayKey) : .unlicensed
        } catch {
            lastErrorMessage = error.localizedDescription
            status = .unlicensed
        }
        isWorking = false
    }

    public func refreshTapped() async {
        guard let key = store.key() else { return }
        await refresh(key: key)
    }

    public func deactivate() async {
        guard let key = store.key(), let activationID = store.activationID() else { return }
        isWorking = true
        try? await client.deactivate(key, activationID)
        try? store.clear()
        status = .unlicensed
        isWorking = false
    }

    private func refresh(key: String) async {
        isWorking = true
        do {
            let license = try await client.validate(key, store.activationID())
            status = license.isValid ? .licensed(displayKey: license.displayKey) : .unlicensed
            if !license.isValid { lastErrorMessage = LicenseError.invalidKey.localizedDescription }
        } catch LicenseError.offline {
            status = .grace
        } catch {
            lastErrorMessage = error.localizedDescription
            status = .unlicensed
        }
        isWorking = false
    }

    public func buy() {
        NSWorkspace.shared.open(Polar.checkoutURL)
    }

    static var machineLabel: String {
        Host.current().localizedName ?? "Mac"
    }
}

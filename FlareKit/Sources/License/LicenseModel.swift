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
        case trial(daysLeft: Int)
        case trialExpired
        case unlicensed
        /// Polar was unreachable but a key was activated before, so the app keeps
        /// working. Being offline must not lock someone out of what they bought.
        case grace
    }

    public static let trialDays = 3

    @ObservationIgnored @Dependency(\.licenseClient) private var client
    @ObservationIgnored @Dependency(\.licenseStore) private var store

    public private(set) var status: Status = .unknown
    public private(set) var isWorking = false
    public var lastErrorMessage: String?

    public var isUnlocked: Bool {
        switch status {
        case .licensed, .grace, .trial: true
        case .unknown, .unlicensed, .trialExpired: false
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
            status = trialStatus()
            return
        }
        await refresh(key: key)
    }

    /// Starts the clock on first launch, then reports what is left of it.
    private func trialStatus() -> Status {
        let start = (try? store.beginTrial()) ?? store.trialStart() ?? .now
        let elapsed = Calendar.current.dateComponents([.day], from: start, to: .now).day ?? 0
        let remaining = Self.trialDays - elapsed
        return remaining > 0 ? .trial(daysLeft: remaining) : .trialExpired
    }

    public var trialDaysLeft: Int? {
        if case .trial(let days) = status { return days }
        return nil
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
            status = trialStatus()
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
        status = trialStatus()
        isWorking = false
    }

    private func refresh(key: String) async {
        isWorking = true
        do {
            let license = try await client.validate(key, store.activationID())
            status = license.isValid ? .licensed(displayKey: license.displayKey) : trialStatus()
            if !license.isValid { lastErrorMessage = LicenseError.invalidKey.localizedDescription }
        } catch LicenseError.offline {
            status = .grace
        } catch {
            lastErrorMessage = error.localizedDescription
            status = trialStatus()
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

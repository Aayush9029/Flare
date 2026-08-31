import Dependencies
import Foundation
import Testing

@testable import FlareKit

@Suite("Licensing")
@MainActor
struct LicenseTests {
    /// An exhausted trial by default, so these tests exercise licensing alone.
    private static var expiredTrial: LicenseStore {
        .ephemeral(trialStart: Calendar.current.date(byAdding: .day, value: -30, to: .now)!)
    }

    private func makeModel(
        store: LicenseStore? = nil,
        client: PolarLicenseClient
    ) -> LicenseModel {
        let store = store ?? Self.expiredTrial
        return withDependencies {
            $0.licenseStore = store
            $0.licenseClient = client
        } operation: {
            LicenseModel()
        }
    }

    nonisolated private static func license(status: String) -> LicenseKey {
        LicenseKey(
            id: "lk_1",
            status: status,
            displayKey: "FLARE-••••-1234",
            expiresAt: nil,
            limitActivations: 3,
            activation: LicenseActivation(id: "act_1", label: "Mac")
        )
    }

    @Test("With no key and no trial left the app is locked")
    func startsLocked() async {
        var client = PolarLicenseClient.testValue
        client.validate = { _, _ in Issue.record("should not validate"); return Self.license(status: "granted") }
        let model = makeModel(client: client)
        await model.start()
        #expect(model.status == .trialExpired)
        #expect(!model.isUnlocked)
    }

    @Test("Activating a granted key unlocks and stores it")
    func activates() async {
        let store = Self.expiredTrial
        var client = PolarLicenseClient.testValue
        client.activate = { _, _ in Self.license(status: "granted") }
        let model = withDependencies {
            $0.licenseStore = store
            $0.licenseClient = client
        } operation: { LicenseModel() }

        await model.activate(key: "flare-abcd-efgh-ijkl")
        #expect(model.isUnlocked)
        #expect(store.key() == "FLARE-ABCD-EFGH-IJKL", "the key is normalised before storing")
        #expect(store.activationID() == "act_1")
    }

    @Test("A revoked key locks the app")
    func revoked() async {
        var client = PolarLicenseClient.testValue
        client.validate = { _, _ in Self.license(status: "revoked") }
        let model = makeModel(store: .ephemeral(key: "FLARE-X", activationID: "act_1", trialStart: Calendar.current.date(byAdding: .day, value: -30, to: .now)!), client: client)
        await model.start()
        #expect(model.status == .trialExpired)
    }

    @Test("Being offline keeps a previously activated Mac working")
    func offlineGrace() async {
        var client = PolarLicenseClient.testValue
        client.validate = { _, _ in throw LicenseError.offline }
        let model = makeModel(store: .ephemeral(key: "FLARE-X", activationID: "act_1", trialStart: Calendar.current.date(byAdding: .day, value: -30, to: .now)!), client: client)
        await model.start()
        #expect(model.status == .grace)
        #expect(model.isUnlocked, "an outage must not lock out a paying customer")
    }

    @Test("An invalid key reports and stays locked")
    func invalid() async {
        var client = PolarLicenseClient.testValue
        client.activate = { _, _ in throw LicenseError.invalidKey }
        let model = makeModel(client: client)
        await model.activate(key: "FLARE-NOPE-NOPE")
        #expect(!model.isUnlocked)
        #expect(model.lastErrorMessage != nil)
    }

    @Test("Deactivating clears the stored key")
    func deactivates() async {
        let store = LicenseStore.ephemeral(
            key: "FLARE-X",
            activationID: "act_1",
            trialStart: Calendar.current.date(byAdding: .day, value: -30, to: .now)!
        )
        var client = PolarLicenseClient.testValue
        client.validate = { _, _ in Self.license(status: "granted") }
        client.deactivate = { _, _ in }
        let model = withDependencies {
            $0.licenseStore = store
            $0.licenseClient = client
        } operation: { LicenseModel() }

        await model.start()
        #expect(model.isUnlocked)
        await model.deactivate()
        #expect(!model.isUnlocked)
        #expect(store.key() == nil)
    }
}

@Suite("Free trial")
@MainActor
struct TrialTests {
    private func model(store: LicenseStore) -> LicenseModel {
        withDependencies {
            $0.licenseStore = store
            $0.licenseClient = .testValue
        } operation: {
            LicenseModel()
        }
    }

    @Test("A first launch starts the trial and unlocks the app")
    func firstLaunchStartsTrial() async {
        let store = LicenseStore.ephemeral()
        let model = model(store: store)
        await model.start()
        #expect(model.isUnlocked)
        #expect(model.trialDaysLeft == LicenseModel.trialDays)
        #expect(store.trialStart() != nil, "the clock must be recorded")
    }

    @Test("A trial part way through reports the days that remain")
    func partwayThrough() async {
        let started = Calendar.current.date(byAdding: .day, value: -2, to: .now)!
        let model = model(store: .ephemeral(trialStart: started))
        await model.start()
        #expect(model.trialDaysLeft == 1)
        #expect(model.isUnlocked)
    }

    @Test("An expired trial locks the app")
    func expired() async {
        let started = Calendar.current.date(byAdding: .day, value: -LicenseModel.trialDays, to: .now)!
        let model = model(store: .ephemeral(trialStart: started))
        await model.start()
        #expect(model.status == .trialExpired)
        #expect(!model.isUnlocked)
    }

    @Test("Reinstalling does not restart the clock")
    func doesNotRestart() async {
        let started = Calendar.current.date(byAdding: .day, value: -2, to: .now)!
        let store = LicenseStore.ephemeral(trialStart: started)
        let first = model(store: store)
        await first.start()
        let second = model(store: store)
        await second.start()
        #expect(second.trialDaysLeft == 1, "beginTrial must be idempotent")
    }
}

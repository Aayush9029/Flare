import Dependencies
import Foundation
import Testing

@testable import FlareKit

@Suite("Licensing")
@MainActor
struct LicenseTests {
    private func makeModel(
        store: LicenseStore = .ephemeral(),
        client: PolarLicenseClient
    ) -> LicenseModel {
        withDependencies {
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

    @Test("With no stored key the app is locked")
    func startsLocked() async {
        var client = PolarLicenseClient.testValue
        client.validate = { _, _ in Issue.record("should not validate"); return Self.license(status: "granted") }
        let model = makeModel(client: client)
        await model.start()
        #expect(model.status == .unlicensed)
        #expect(!model.isUnlocked)
    }

    @Test("Activating a granted key unlocks and stores it")
    func activates() async {
        let store = LicenseStore.ephemeral()
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
        let model = makeModel(store: .ephemeral(key: "FLARE-X", activationID: "act_1"), client: client)
        await model.start()
        #expect(model.status == .unlicensed)
    }

    @Test("Being offline keeps a previously activated Mac working")
    func offlineGrace() async {
        var client = PolarLicenseClient.testValue
        client.validate = { _, _ in throw LicenseError.offline }
        let model = makeModel(store: .ephemeral(key: "FLARE-X", activationID: "act_1"), client: client)
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
        let store = LicenseStore.ephemeral(key: "FLARE-X", activationID: "act_1")
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

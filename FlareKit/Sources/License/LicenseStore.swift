import Dependencies
import DependenciesMacros
import Foundation

/// The license key, its activation and the trial start, as a 0600 file beside the
/// auth tokens. They lived in the Keychain, whose ACL is bound to the signing
/// identity: every re-signed build asked for permission again on launch. Even a
/// one-time read of the old items asks, so nothing is migrated.
@DependencyClient
public struct LicenseStore: Sendable {
    public var key: @Sendable () -> String?
    public var activationID: @Sendable () -> String?
    public var save: @Sendable (String, String?) throws -> Void
    public var clear: @Sendable () throws -> Void
    public var trialStart: @Sendable () -> Date?
    public var beginTrial: @Sendable () throws -> Date
}

struct LicenseFile: Codable, Equatable {
    var key: String?
    var activationID: String?
    var trialStart: Date?
}

extension LicenseStore: DependencyKey {
    public static let url = URL.applicationSupportDirectory
        .appending(path: "Flare", directoryHint: .isDirectory)
        .appending(path: "license.json")

    public static let liveValue = Self(
        key: { load().key },
        activationID: { load().activationID },
        save: { key, activationID in
            var file = load()
            file.key = key
            if let activationID { file.activationID = activationID }
            try write(file)
        },
        clear: {
            var file = load()
            file.key = nil
            file.activationID = nil
            try write(file)
        },
        trialStart: { load().trialStart },
        beginTrial: {
            var file = load()
            if let existing = file.trialStart { return existing }
            let now = Date()
            file.trialStart = now
            try write(file)
            return now
        }
    )

    private static let lock = NSLock()

    private static func load() -> LicenseFile {
        lock.lock(); defer { lock.unlock() }
        guard let data = try? Data(contentsOf: url), let file = try? decoder.decode(LicenseFile.self, from: data) else {
            return LicenseFile()
        }
        return file
    }

    private static func write(_ file: LicenseFile) throws {
        lock.lock(); defer { lock.unlock() }
        try unlockedWrite(file)
    }

    private static func unlockedWrite(_ file: LicenseFile) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try encoder.encode(file).write(to: url, options: [.atomic])
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}

extension LicenseStore: TestDependencyKey {
    public static let testValue = Self.ephemeral()

    public static func ephemeral(
        key: String? = nil,
        activationID: String? = nil,
        trialStart: Date? = nil
    ) -> Self {
        let box = LockedBox((key: key, activation: activationID, trial: trialStart))
        return Self(
            key: { box.value.key },
            activationID: { box.value.activation },
            save: { key, activation in
                box.value = (key, activation ?? box.value.activation, box.value.trial)
            },
            clear: { box.value = (nil, nil, box.value.trial) },
            trialStart: { box.value.trial },
            beginTrial: {
                if let existing = box.value.trial { return existing }
                let now = Date()
                box.value = (box.value.key, box.value.activation, now)
                return now
            }
        )
    }
}

public extension DependencyValues {
    var licenseStore: LicenseStore {
        get { self[LicenseStore.self] }
        set { self[LicenseStore.self] = newValue }
    }
}

import Dependencies
import DependenciesMacros
import Foundation

/// Only the organization id ships in the binary. It is a public identifier, not a
/// credential: the organization access token can refund and delete, and must never
/// reach an app bundle.
public enum Polar {
    public static let organizationID = "0db5a0f0-ae29-4749-b5d2-a44cee706d1a"
    public static let productID = "d69da629-669f-41fc-8f61-5f1f5cdc0064"
    public static let checkoutURL = URL(
        string: "https://buy.polar.sh/polar_cl_K82sNwXB3j2OzYvLMORq8ZDriwpXW5gMWRhyC18TopY"
    )!
    static let api = URL(string: "https://api.polar.sh/v1")!
    /// Sent on both activate and validate. Polar rejects a validate whose
    /// conditions differ from the ones used at activation.
    static let conditions = ["major_version": 1]
}

public struct LicenseActivation: Codable, Sendable, Equatable {
    public let id: String
    public let label: String?
}

public struct LicenseKey: Codable, Sendable, Equatable {
    public let id: String
    public let status: String
    public let displayKey: String?
    public let expiresAt: Date?
    public let limitActivations: Int?
    public let activation: LicenseActivation?

    public var isValid: Bool {
        status == "granted" && (expiresAt.map { $0 > .now } ?? true)
    }
}

public enum LicenseError: Error, LocalizedError, Equatable {
    case invalidKey
    case activationLimitReached
    case rateLimited
    case server(Int)
    case offline

    public var errorDescription: String? {
        switch self {
        case .invalidKey: "That license key is not valid for Flare."
        case .activationLimitReached:
            "This license is already active on the maximum number of Macs. Deactivate one from your Polar customer portal."
        case .rateLimited: "Too many attempts. Try again in a moment."
        case .server(let code): "Polar returned an error (\(code))."
        case .offline: "Could not reach Polar. Check your connection."
        }
    }
}

@DependencyClient
public struct PolarLicenseClient: Sendable {
    public var activate: @Sendable (_ key: String, _ label: String) async throws -> LicenseKey
    public var validate: @Sendable (_ key: String, _ activationID: String?) async throws -> LicenseKey
    public var deactivate: @Sendable (_ key: String, _ activationID: String) async throws -> Void
}

extension PolarLicenseClient: DependencyKey {
    public static let liveValue = Self(
        activate: { key, label in
            struct Response: Decodable { let licenseKey: LicenseKey }
            let response: Response = try await post(
                "customer-portal/license-keys/activate",
                [
                    "key": key,
                    "organization_id": Polar.organizationID,
                    "label": label,
                    "conditions": Polar.conditions,
                ]
            )
            return response.licenseKey
        },
        validate: { key, activationID in
            var body: [String: Any] = [
                "key": key,
                "organization_id": Polar.organizationID,
                "conditions": Polar.conditions,
            ]
            if let activationID { body["activation_id"] = activationID }
            return try await post("customer-portal/license-keys/validate", body)
        },
        deactivate: { key, activationID in
            let _: EmptyResponse = try await post(
                "customer-portal/license-keys/deactivate",
                [
                    "key": key,
                    "organization_id": Polar.organizationID,
                    "activation_id": activationID,
                ]
            )
        }
    )

    private struct EmptyResponse: Decodable {}

    private static func post<T: Decodable>(_ path: String, _ body: [String: Any]) async throws -> T {
        var request = URLRequest(url: Polar.api.appending(path: path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 15

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw LicenseError.offline
        }

        guard let http = response as? HTTPURLResponse else { throw LicenseError.server(0) }
        switch http.statusCode {
        case 200..<300:
            if T.self == EmptyResponse.self { return EmptyResponse() as! T }
            return try decoder.decode(T.self, from: data)
        case 403: throw LicenseError.activationLimitReached
        case 404: throw LicenseError.invalidKey
        case 429: throw LicenseError.rateLimited
        default: throw LicenseError.server(http.statusCode)
        }
    }

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            let formatter = ISO8601DateFormatter()
            // Polar emits fractional seconds; the default options reject them.
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: text) { return date }
            formatter.formatOptions = [.withInternetDateTime]
            guard let date = formatter.date(from: text) else {
                throw DecodingError.dataCorruptedError(
                    in: try decoder.singleValueContainer(),
                    debugDescription: "unparsable date \(text)"
                )
            }
            return date
        }
        return decoder
    }()
}

extension PolarLicenseClient: TestDependencyKey {
    public static let testValue = Self()

    /// A licence that always validates, for tests of everything except licensing.
    public static let granted = Self(
        activate: { _, _ in grantedKey },
        validate: { _, _ in grantedKey },
        deactivate: { _, _ in }
    )

    private static let grantedKey = LicenseKey(
        id: "lk_test",
        status: "granted",
        displayKey: "FLARE-••••-TEST",
        expiresAt: nil,
        limitActivations: 3,
        activation: LicenseActivation(id: "act_1", label: "Test")
    )
}

public extension DependencyValues {
    var licenseClient: PolarLicenseClient {
        get { self[PolarLicenseClient.self] }
        set { self[PolarLicenseClient.self] = newValue }
    }
}

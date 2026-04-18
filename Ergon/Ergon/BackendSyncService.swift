import Foundation

enum BackendEndpointMode: String, CaseIterable, Identifiable {
    case emulator
    case production
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .emulator:
            return "Emulator"
        case .production:
            return "Production"
        case .custom:
            return "Custom"
        }
    }
}

struct BackendUserProfilePayload: Encodable {
    let uid: String?
    let email: String?
    let display_name: String?
    let fcm_token: String?
}

struct BackendDailyInsightPayload: Encodable {
    let uid: String?
    let date_key: String
    let risk_score: Double
    let completed_microtask: Bool
    let mental_energy: Double
    let sleep_quality: Double
    let digital_disconnect: Double
}

struct BackendTokenVerificationResult: Decodable {
    let ok: Bool
    let uid: String
    let email: String?
    let issued_at: Int?
    let expires_at: Int?
    let error: String?
}

private struct BackendFunctionResponse: Decodable {
    let ok: Bool
    let error: String?
}

enum BackendSyncError: LocalizedError {
    case invalidBaseURL
    case invalidHTTPResponse
    case missingIDToken
    case missingAPIKey
    case serverError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            return "Backend base URL is invalid."
        case .invalidHTTPResponse:
            return "Backend returned an invalid HTTP response."
        case .missingIDToken:
            return "Unable to resolve Firebase ID token. Add API key or manual token in Profile > Backend Debug."
        case .missingAPIKey:
            return "Firebase API key is required for automatic auth in production/custom mode."
        case let .serverError(statusCode, message):
            return "Backend error (\(statusCode)): \(message)"
        }
    }
}

final class BackendSyncService {
    private enum Constants {
        static let backendUIDKey = "ergon_backend_uid"
        static let backendModeKey = "ergon_backend_mode"
        static let backendCustomBaseURLKey = "ergon_backend_custom_base_url"
        static let backendBaseURLKey = "ergon_backend_base_url"
        static let backendIDTokenKey = "ergon_backend_id_token"
        static let defaultProjectID = "ergon-dev"
        static let region = "us-central1"
    }

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    static func resolveOrCreateUID(defaults: UserDefaults = .standard) -> String {
        if let existing = defaults.string(forKey: Constants.backendUIDKey), !existing.isEmpty {
            return existing
        }

        let generated = UUID().uuidString.lowercased()
        defaults.set(generated, forKey: Constants.backendUIDKey)
        return generated
    }

    static func endpointMode(defaults: UserDefaults = .standard) -> BackendEndpointMode {
        let raw = defaults.string(forKey: Constants.backendModeKey) ?? defaultEndpointMode().rawValue
        return BackendEndpointMode(rawValue: raw) ?? defaultEndpointMode()
    }

    static func setEndpointMode(_ mode: BackendEndpointMode, defaults: UserDefaults = .standard) {
        defaults.set(mode.rawValue, forKey: Constants.backendModeKey)
    }

    static func customBaseURL(defaults: UserDefaults = .standard) -> String {
        return defaults.string(forKey: Constants.backendCustomBaseURLKey) ?? ""
    }

    static func setCustomBaseURL(_ value: String, defaults: UserDefaults = .standard) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        defaults.set(trimmed, forKey: Constants.backendCustomBaseURLKey)
    }

    static func backendIDToken(defaults: UserDefaults = .standard) -> String {
        return defaults.string(forKey: Constants.backendIDTokenKey) ?? ""
    }

    static func setBackendIDToken(_ token: String, defaults: UserDefaults = .standard) {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        defaults.set(trimmed, forKey: Constants.backendIDTokenKey)
    }

    static func clearLegacyBaseURLOverride(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: Constants.backendBaseURLKey)
    }

    static func dateKeyUTC(from date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    func upsertUserProfile(payload: BackendUserProfilePayload) async throws {
        _ = try await post(functionName: "upsertUserProfile", payload: payload)
    }

    func submitDailyInsight(payload: BackendDailyInsightPayload) async throws {
        _ = try await post(functionName: "submitDailyInsight", payload: payload)
    }

    func verifyAuthToken() async throws -> BackendTokenVerificationResult {
        guard let endpoint = endpointURL(functionName: "verifyMobileAuth") else {
            throw BackendSyncError.invalidBaseURL
        }

        let request = try await makeAuthorizedRequest(url: endpoint, method: "GET", body: nil)
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BackendSyncError.invalidHTTPResponse
        }

        let decoded = try? JSONDecoder().decode(BackendTokenVerificationResult.self, from: data)

        guard (200...299).contains(httpResponse.statusCode) else {
            throw BackendSyncError.serverError(
                statusCode: httpResponse.statusCode,
                message: decodeErrorMessage(from: data, fallbackStatusCode: httpResponse.statusCode)
            )
        }

        guard let decoded else {
            throw BackendSyncError.invalidHTTPResponse
        }

        if !decoded.ok {
            throw BackendSyncError.serverError(
                statusCode: httpResponse.statusCode,
                message: decoded.error ?? "Unknown token verification failure"
            )
        }

        return decoded
    }

    private func post<T: Encodable>(functionName: String, payload: T) async throws -> BackendFunctionResponse {
        guard let endpoint = endpointURL(functionName: functionName) else {
            throw BackendSyncError.invalidBaseURL
        }

        let request = try await makeAuthorizedRequest(
            url: endpoint,
            method: "POST",
            body: try JSONEncoder().encode(payload)
        )

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BackendSyncError.invalidHTTPResponse
        }

        let decoded = try? JSONDecoder().decode(BackendFunctionResponse.self, from: data)

        guard (200...299).contains(httpResponse.statusCode) else {
            throw BackendSyncError.serverError(
                statusCode: httpResponse.statusCode,
                message: decodeErrorMessage(from: data, fallbackStatusCode: httpResponse.statusCode)
            )
        }

        if let decoded, !decoded.ok {
            throw BackendSyncError.serverError(statusCode: httpResponse.statusCode, message: decoded.error ?? "Unknown backend failure")
        }

        return decoded ?? BackendFunctionResponse(ok: true, error: nil)
    }

    private func makeAuthorizedRequest(url: URL, method: String, body: Data?) async throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let idToken = try await resolveIDToken()
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = body

        return request
    }

    private func resolveIDToken() async throws -> String {
        let manualToken = Self.backendIDToken().trimmingCharacters(in: .whitespacesAndNewlines)
        if !manualToken.isEmpty {
            return manualToken
        }

        do {
            return try await FirebaseAuthTokenProvider.shared.fetchValidIDToken(endpointMode: Self.endpointMode())
        } catch let error as FirebaseAuthTokenProviderError {
            switch error {
            case .missingAPIKey:
                throw BackendSyncError.missingAPIKey
            default:
                throw BackendSyncError.missingIDToken
            }
        } catch {
            throw BackendSyncError.missingIDToken
        }
    }

    private func decodeErrorMessage(from data: Data, fallbackStatusCode: Int) -> String {
        if let decoded = try? JSONDecoder().decode(BackendFunctionResponse.self, from: data),
           let error = decoded.error,
           !error.isEmpty {
            return error
        }

        return HTTPURLResponse.localizedString(forStatusCode: fallbackStatusCode)
    }

    private func endpointURL(functionName: String) -> URL? {
        let baseURLString = Self.resolvedBaseURLString()

        guard let baseURL = URL(string: baseURLString) else {
            return nil
        }

        return baseURL.appendingPathComponent(functionName)
    }

    private static func emulatorBaseURLString() -> String {
        return "http://127.0.0.1:5001/\(Constants.defaultProjectID)/\(Constants.region)"
    }

    private static func productionBaseURLString() -> String {
        return "https://\(Constants.region)-\(Constants.defaultProjectID).cloudfunctions.net"
    }

    private static func defaultEndpointMode() -> BackendEndpointMode {
    #if targetEnvironment(simulator)
        return .emulator
    #else
        return .production
    #endif
    }

    static func resolvedBaseURLString(defaults: UserDefaults = .standard) -> String {
        let legacyOverride = defaults.string(forKey: Constants.backendBaseURLKey)?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let legacyOverride, !legacyOverride.isEmpty {
            return legacyOverride
        }

        switch endpointMode(defaults: defaults) {
        case .emulator:
            return emulatorBaseURLString()
        case .production:
            return productionBaseURLString()
        case .custom:
            let custom = customBaseURL(defaults: defaults)
            return custom.isEmpty ? productionBaseURLString() : custom
        }
    }
}

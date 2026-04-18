import Foundation

enum FirebaseAuthTokenProviderError: LocalizedError {
    case invalidURL
    case invalidResponse
    case missingAPIKey
    case authFailed(message: String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Firebase Auth endpoint URL is invalid."
        case .invalidResponse:
            return "Firebase Auth returned an invalid response."
        case .missingAPIKey:
            return "Firebase API key is required for automatic auth."
        case let .authFailed(message):
            return "Firebase Auth failed: \(message)"
        }
    }
}

private struct AnonymousSignInResponse: Decodable {
    let idToken: String
    let refreshToken: String
    let expiresIn: String
    let localId: String
}

private struct RefreshTokenResponse: Decodable {
    let id_token: String
    let refresh_token: String
    let expires_in: String
    let user_id: String
}

private struct FirebaseErrorEnvelope: Decodable {
    struct FirebaseErrorBody: Decodable {
        let message: String
    }

    let error: FirebaseErrorBody
}

actor FirebaseAuthTokenProvider {
    static let shared = FirebaseAuthTokenProvider()

    private enum Keys {
        static let apiKey = "ergon_firebase_api_key"
        static let idToken = "ergon_firebase_id_token"
        static let refreshToken = "ergon_firebase_refresh_token"
        static let tokenExpiry = "ergon_firebase_token_expiry"
        static let uid = "ergon_firebase_uid"
    }

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    static func apiKey(defaults: UserDefaults = .standard) -> String {
        let configured = defaults.string(forKey: Keys.apiKey) ?? ""
        if !configured.isEmpty {
            return configured
        }
        
        if let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: path),
           let apiKey = dict["FIREBASE_API_KEY"] as? String {
            return apiKey
        }
        
        return ""
    }

    static func setAPIKey(_ key: String, defaults: UserDefaults = .standard) {
        defaults.set(key.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Keys.apiKey)
    }

    static func currentUID(defaults: UserDefaults = .standard) -> String {
        return defaults.string(forKey: Keys.uid) ?? ""
    }

    static func clearSession(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: Keys.idToken)
        defaults.removeObject(forKey: Keys.refreshToken)
        defaults.removeObject(forKey: Keys.tokenExpiry)
        defaults.removeObject(forKey: Keys.uid)
    }

    func fetchValidIDToken(endpointMode: BackendEndpointMode) async throws -> String {
        let defaults = UserDefaults.standard

        if let token = defaults.string(forKey: Keys.idToken),
           let expiry = defaults.object(forKey: Keys.tokenExpiry) as? Date,
           expiry.timeIntervalSinceNow > 60 {
            return token
        }

        let apiKey = try resolvedAPIKey(endpointMode: endpointMode, defaults: defaults)

        if let storedRefreshToken = defaults.string(forKey: Keys.refreshToken), !storedRefreshToken.isEmpty {
            do {
                let refreshed = try await refreshToken(
                    endpointMode: endpointMode,
                    apiKey: apiKey,
                    refreshToken: storedRefreshToken
                )
                persist(
                    idToken: refreshed.id_token,
                    refreshToken: refreshed.refresh_token,
                    expiresIn: refreshed.expires_in,
                    uid: refreshed.user_id,
                    defaults: defaults
                )
                return refreshed.id_token
            } catch {
                defaults.removeObject(forKey: Keys.refreshToken)
            }
        }

        let signedIn = try await signInAnonymously(endpointMode: endpointMode, apiKey: apiKey)
        persist(
            idToken: signedIn.idToken,
            refreshToken: signedIn.refreshToken,
            expiresIn: signedIn.expiresIn,
            uid: signedIn.localId,
            defaults: defaults
        )
        return signedIn.idToken
    }

    private func resolvedAPIKey(endpointMode: BackendEndpointMode, defaults: UserDefaults) throws -> String {
        // 1. Check UserDefaults (manual override via Debug UI)
        let configured = (defaults.string(forKey: Keys.apiKey) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !configured.isEmpty {
            return configured
        }

        // 2. Check Secrets.plist (local configuration)
        if let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: path),
           let apiKey = dict["FIREBASE_API_KEY"] as? String,
           !apiKey.isEmpty {
            return apiKey
        }

        // 3. Emulator fallback
        if endpointMode == .emulator {
            return "demo-key"
        }

        throw FirebaseAuthTokenProviderError.missingAPIKey
    }

    private func signInAnonymously(
        endpointMode: BackendEndpointMode,
        apiKey: String
    ) async throws -> AnonymousSignInResponse {
        guard let url = anonymousSignInURL(endpointMode: endpointMode, apiKey: apiKey) else {
            throw FirebaseAuthTokenProviderError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["returnSecureToken": true])

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw FirebaseAuthTokenProviderError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw FirebaseAuthTokenProviderError.authFailed(message: decodeErrorMessage(from: data, statusCode: httpResponse.statusCode))
        }

        guard let decoded = try? JSONDecoder().decode(AnonymousSignInResponse.self, from: data) else {
            throw FirebaseAuthTokenProviderError.invalidResponse
        }

        return decoded
    }

    private func refreshToken(
        endpointMode: BackendEndpointMode,
        apiKey: String,
        refreshToken: String
    ) async throws -> RefreshTokenResponse {
        guard let url = refreshTokenURL(endpointMode: endpointMode, apiKey: apiKey) else {
            throw FirebaseAuthTokenProviderError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let formBody = "grant_type=refresh_token&refresh_token=\(urlEncoded(refreshToken))"
        request.httpBody = formBody.data(using: .utf8)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw FirebaseAuthTokenProviderError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw FirebaseAuthTokenProviderError.authFailed(message: decodeErrorMessage(from: data, statusCode: httpResponse.statusCode))
        }

        guard let decoded = try? JSONDecoder().decode(RefreshTokenResponse.self, from: data) else {
            throw FirebaseAuthTokenProviderError.invalidResponse
        }

        return decoded
    }

    private func persist(
        idToken: String,
        refreshToken: String,
        expiresIn: String,
        uid: String,
        defaults: UserDefaults
    ) {
        let expiresInSeconds = TimeInterval(expiresIn) ?? 3600
        let expiryDate = Date().addingTimeInterval(max(120, expiresInSeconds - 60))

        defaults.set(idToken, forKey: Keys.idToken)
        defaults.set(refreshToken, forKey: Keys.refreshToken)
        defaults.set(expiryDate, forKey: Keys.tokenExpiry)
        defaults.set(uid, forKey: Keys.uid)
    }

    private func anonymousSignInURL(endpointMode: BackendEndpointMode, apiKey: String) -> URL? {
        var components = URLComponents()
        components.queryItems = [URLQueryItem(name: "key", value: apiKey)]

        switch endpointMode {
        case .emulator:
            components.scheme = "http"
            components.host = "127.0.0.1"
            components.port = 9099
            components.path = "/identitytoolkit.googleapis.com/v1/accounts:signUp"
        case .production, .custom:
            components.scheme = "https"
            components.host = "identitytoolkit.googleapis.com"
            components.path = "/v1/accounts:signUp"
        }

        return components.url
    }

    private func refreshTokenURL(endpointMode: BackendEndpointMode, apiKey: String) -> URL? {
        var components = URLComponents()
        components.queryItems = [URLQueryItem(name: "key", value: apiKey)]

        switch endpointMode {
        case .emulator:
            components.scheme = "http"
            components.host = "127.0.0.1"
            components.port = 9099
            components.path = "/securetoken.googleapis.com/v1/token"
        case .production, .custom:
            components.scheme = "https"
            components.host = "securetoken.googleapis.com"
            components.path = "/v1/token"
        }

        return components.url
    }

    private func decodeErrorMessage(from data: Data, statusCode: Int) -> String {
        if let decoded = try? JSONDecoder().decode(FirebaseErrorEnvelope.self, from: data) {
            return decoded.error.message
        }

        return HTTPURLResponse.localizedString(forStatusCode: statusCode)
    }

    private func urlEncoded(_ value: String) -> String {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}

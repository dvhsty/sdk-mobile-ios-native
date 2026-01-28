import Foundation

public class Session: ObservableObject {
    private let storage: Storage
    private let logging: Logging

    @Published public internal(set) var loginInProgress: Bool = false
    @Published public internal(set) var profile: Profile?

    init(storage: Storage, logging: Logging) {
        self.storage = storage
        self.logging = logging
    }

    @MainActor
    func load() {
        if let profileData = storage.get(key: "profile")?.data(using: .utf8) {
            do {
                profile = try JSONDecoder().decode(Profile.self, from: profileData)
                logging.debug("Session loaded")
            } catch {
                logging.debug("Failed to load profile: \(error.localizedDescription)")
            }
        }
    }

    @MainActor
    func update(tokenResponse: TokenResponse) {
        loginInProgress = false
        profile = Profile(tokenResponse: tokenResponse)

        guard let profileData = try? String(decoding: JSONEncoder().encode(profile), as: UTF8.self) else {
            logging.debug("Failed to serialize session content")
            assert(false, "Failed to serialize session content")
        }

        guard storage.set(key: "profile", value: profileData) else {
            logging.debug("Failed to store content to storage")
            assert(false, "Failed to store content to storage")
        }
        logging.debug("Profile successfully updated")
    }

    /// Invalidates session and clears locally stored session information
    @MainActor
    func clear() {
        logging.debug("Session cleared")
        loginInProgress = false
        profile = nil
        storage.delete(key: "profile")
    }
}

public struct Profile: Codable {
    enum CodingKeys: String, CodingKey {
        case tokenResponse
        case accessTokenExpiresAt
    }

    var tokenResponse: TokenResponse
    var accessTokenExpiresAt: Date

    public internal(set) var claims: [String: Any]

    init(tokenResponse: TokenResponse) {
        self.tokenResponse = tokenResponse
        accessTokenExpiresAt = Date(timeIntervalSinceNow: Double(tokenResponse.expiresIn))

        claims = JWTUtils.parseJWT(tokenResponse.idToken)
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tokenResponse = try container.decode(TokenResponse.self, forKey: .tokenResponse)
        accessTokenExpiresAt = try container.decode(Date.self, forKey: .accessTokenExpiresAt)

        claims = JWTUtils.parseJWT(tokenResponse.idToken)
    }
}

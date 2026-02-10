import Foundation

class OIDCHandlerService {
    private let httpService: HttpService
    private let logging: Logging

    init(httpService: HttpService, logging: Logging) {
        self.httpService = httpService
        self.logging = logging
    }

    func handleCall(url: URL) async throws -> [String: String] {
        logging.debug("Handling call to: \(url.scheme ?? "unkown")://\(url.host ?? "")\(url.path)")
        var location: String
        if url.scheme == "https" {
            let response = try await httpService.get(url: url, acceptHeader: "text/html")
            let responseStatusCode: Int = response.httpResponse.statusCode

            guard [200, 302, 303].contains(responseStatusCode) else {
                logging.debug("Unexpected response with status code: [\(responseStatusCode)]")
                throw NativeSDKError.httpError(statusCode: response.httpResponse.statusCode)
            }

            if responseStatusCode == 200,
               let responseUrl = response.httpResponse.url,
               responseUrl.host == url.host, responseUrl.path == "/oauth2/error" {
                return getQueryParameters(from: responseUrl)
            }

            guard let responseBody = String(data: response.data, encoding: .utf8),
                  !responseBody.isEmpty else {
                logging.warn("Expected response body to contain redirect URL but was not found or could not be decoded")
                throw NativeSDKError.invalidCallback(
                    reason: "Invalid response received"
                )
            }

            location = responseBody

        } else {
            location = url.absoluteString
        }

        guard let locationUrl = URL(string: location) else {
            throw NativeSDKError.technical(message: "Location url could not be parsed", details: ["url": location])
        }
        return getQueryParameters(from: locationUrl)
    }

    func logout(url: URL) async throws -> String? {
        let response = try await httpService.get(url: url, acceptHeader: "text/html")
        let responseStatusCode: Int = response.httpResponse.statusCode

        return switch responseStatusCode {
        case 200: response.httpResponse.url?.absoluteString
        case 302: response.httpResponse.value(forHTTPHeaderField: "Location")
        default: throw NativeSDKError.httpError(statusCode: response.httpResponse.statusCode)
        }
    }

    func tokenExchange(url: URL, params: TokenExchangeParams) async throws -> TokenResponse {
        let response = try await httpService.post(
            url: url,
            bodyContent: params.asFormData(),
            contentType: "application/x-www-form-urlencoded"
        )

        if response.httpResponse.statusCode != 200 {
            throw NativeSDKError.httpError(statusCode: response.httpResponse.statusCode)
        }

        return try JSONDecoder().decode(TokenResponse.self, from: response.data)
    }

    func tokenRefresh(url: URL, params: TokenRefreshParams) async throws -> TokenResponse {
        let response = try await httpService.post(
            url: url,
            bodyContent: params.asFormData(),
            contentType: "application/x-www-form-urlencoded"
        )

        if response.httpResponse.statusCode != 200 {
            throw NativeSDKError.httpError(statusCode: response.httpResponse.statusCode)
        }

        return try JSONDecoder().decode(TokenResponse.self, from: response.data)
    }

    private func getQueryParameters(from url: URL) -> [String: String] {
        var params = [String: String]()
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryItems = components.queryItems {
            for queryItem in queryItems {
                params[queryItem.name] = queryItem.value
            }
        }

        return params
    }

    func revoke(issuer: URL, params: RevokeParams) async throws {
        let revokeEndpoint = issuer.appendingPathComponent("/oauth2/revoke")

        let response = try await httpService.post(
            url: revokeEndpoint,
            bodyContent: params.asFormData(),
            contentType: "application/x-www-form-urlencoded"
        )

        if response.httpResponse.statusCode != 200 {
            throw NativeSDKError.httpError(statusCode: response.httpResponse.statusCode)
        }
    }
}

struct OidcParams {
    init(
        onSuccess: @escaping () -> Void,
        onError: @escaping (Error) -> Void,
        prefersEphemeralWebBrowserSession: Bool
    ) {
        codeVerifier = OIDCParamGenerator.generateCodeVerifier()
        codeChallenge = OIDCParamGenerator.generateCodeChallenge(from: codeVerifier)
        state = OIDCParamGenerator.generateState()
        nonce = OIDCParamGenerator.generateNonce()

        self.onSuccess = onSuccess
        self.onError = onError
        self.prefersEphemeralWebBrowserSession = prefersEphemeralWebBrowserSession
    }

    let codeVerifier: String
    let codeChallenge: String
    let state: String
    let nonce: String

    let onSuccess: () -> Void
    let onError: (Error) -> Void
    let prefersEphemeralWebBrowserSession: Bool
}

struct TokenExchangeParams {
    let code: String
    let codeVerifier: String

    let redirectURI: String
    let clientId: String

    let nonce: String

    init(
        code: String,
        codeVerifier: String,
        redirectURI: String,
        clientId: String
    ) {
        self.code = code
        self.codeVerifier = codeVerifier

        self.redirectURI = redirectURI
        self.clientId = clientId

        nonce = OIDCParamGenerator.generateNonce()
    }

    func asFormData() throws -> Data {
        let params: [String: String] = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": redirectURI,
            "client_id": clientId,
            "code_verifier": codeVerifier,
            "nonce": nonce,
        ]

        var urlComponents = URLComponents()
        urlComponents.queryItems = params.map { key, value in
            URLQueryItem(name: key, value: value)
        }

        guard let data = urlComponents.percentEncodedQuery?.data(using: .utf8) else {
            throw NativeSDKError.technical(message: "Failed to prepare token exchange request data")
        }

        return data
    }
}

struct TokenRefreshParams {
    let refreshToken: String
    let clientId: String

    func asFormData() throws -> Data {
        let params: [String: String] = [
            "grant_type": "refresh_token",
            "client_id": clientId,
            "refresh_token": refreshToken,
        ]

        var urlComponents = URLComponents()
        urlComponents.queryItems = params.map { key, value in
            URLQueryItem(name: key, value: value)
        }

        guard let data = urlComponents.percentEncodedQuery?.data(using: .utf8) else {
            throw NativeSDKError.technical(message: "Failed to prepare token refresh request data")
        }

        return data
    }
}

struct RevokeParams {
    let clientId: String
    let token: String
    let tokenTypeHint: String

    func asFormData() throws -> Data {
        let params: [String: String] = [
            "client_id": clientId,
            "token": token,
            "token_type_hint": tokenTypeHint,
        ]

        var urlComponents = URLComponents()
        urlComponents.queryItems = params.map { key, value in
            URLQueryItem(name: key, value: value)
        }

        guard let data = urlComponents.percentEncodedQuery?.data(using: .utf8) else {
            throw NativeSDKError.technical(message: "Failed to prepare revoke request data")
        }

        return data
    }
}

struct TokenResponse: Codable {
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case idToken = "id_token"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
    }

    var accessToken: String
    var idToken: String
    var expiresIn: Int
    var refreshToken: String?
}

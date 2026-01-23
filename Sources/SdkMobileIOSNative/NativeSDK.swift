import Foundation

public class NativeSDK {
    let issuer: URL
    let clientId: String
    let redirectURI: URL
    let postLogoutURI: URL
    let mode: SdkMode
    let logging: Logging

    var loginController: LoginController?

    public let session: Session

    private let httpService: HttpService
    private let oidcHandlerService: OIDCHandlerService

    public init(
        issuer: URL,
        clientId: String,
        redirectURI: URL,
        postLogoutURI: URL,
        storage: Storage = KeyChain(),
        mode: SdkMode = .ios,
        logging: Logging = DefaultLogging()
    ) {
        self.issuer = issuer
        self.clientId = clientId
        self.redirectURI = redirectURI
        self.postLogoutURI = postLogoutURI
        self.mode = mode
        self.logging = logging

        httpService = HttpService(logging: logging)
        oidcHandlerService = OIDCHandlerService(httpService: httpService, logging: logging)

        session = Session(storage: storage, logging: logging)
    }

    public func initializeSession() async throws {
        await session.load()
        try await refreshTokensIfNeeded()
    }

    public func login(
        parameters: LoginParameters?
    ) async throws -> Profile {
        return try await withCheckedThrowingContinuation { continuation in
            Task {
                await login(
                    parameters: parameters,
                    onSuccess: {
                        continuation.resume(returning: self.session.profile!)
                    },
                    onError: { err in
                        continuation.resume(throwing: err)
                    }
                )
            }
        }
    }

    public func login(
        parameters: LoginParameters?,
        onSuccess: @escaping () -> Void,
        onError: @escaping (Error) -> Void
    ) async {
        logging.info("Starting login flow")
        let oidcParams = OidcParams(
            onSuccess: onSuccess,
            onError: onError,
            prefersEphemeralWebBrowserSession: parameters?.prefersEphemeralWebBrowserSession ?? false
        )

        let authEndpoint = issuer.appendingPathComponent("/oauth2/auth")
        var urlComponents = URLComponents(url: authEndpoint, resolvingAgainstBaseURL: false)!

        urlComponents.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(
                name: "redirect_uri",
                value: redirectURI.absoluteString
            ),
            URLQueryItem(name: "state", value: oidcParams.state),
            URLQueryItem(name: "nonce", value: oidcParams.nonce),
            URLQueryItem(
                name: "code_challenge",
                value: oidcParams.codeChallenge
            ),
            URLQueryItem(name: "code_challenge_method", value: "S256"),

            URLQueryItem(
                name: "scope",
                value: (parameters?.scopes ?? ["openid", "profile"]).joined(
                    separator: " "
                )
            ),
            URLQueryItem(name: "acr_values", value: parameters?.acrValue),
            URLQueryItem(name: "login_hint", value: parameters?.loginHint),
            URLQueryItem(name: "prompt", value: parameters?.prompt),
            URLQueryItem(name: "sdk", value: mode.rawValue),
            URLQueryItem(
                name: "audience",
                value: parameters?.audiences?.map {
                    $0.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                .filter { !$0.isEmpty }
                .nilIfEmpty?
                .joined(separator: " ")
            ),
        ]

        guard let url = urlComponents.url else {
            logging.debug("Unable to generate /auth url")
            assert(false, "Unable to generate /auth url")
        }

        do {
            let parameters = try await oidcHandlerService.handleCall(url: url)

            guard let sessionId = parameters["session_id"] else {
                try await continueFlow(oidcParams: oidcParams, queryParameters: parameters)
                return
            }

            let loginHandlerService = LoginHandlerService(
                httpService: httpService,
                issuer: issuer,
                sessionId: sessionId,
                logging: logging
            )
            let loginController = LoginController(
                nativeSDK: self,
                loginHandlerService: loginHandlerService,
                oidcParams: oidcParams,
                logging: logging
            )

            try await loginController.initialize()
            self.loginController = loginController

            await MainActor.run {
                self.session.loginInProgress = true
            }
        } catch {
            logging.error("Failed to log in", error: error)
            onError(NativeSDKError.unknownError(source: error))
        }
    }

    public func continueFlow(uri: URL) async {
        guard let oidcParams = loginController?.oidcParams else {
            assert(false, "Called continueFlow in invalid state")
        }

        do {
            let parameters = try await oidcHandlerService.handleCall(url: uri)
            await continueFlow(oidcParams: oidcParams, queryParameters: parameters)
        } catch {
            await MainActor.run {
                cleanup()
                oidcParams.onError(NativeSDKError.unknownError(source: error))
            }
        }
    }

    public func cancelFlow(error: NativeSDKError? = nil) {
        logging.xEventId = nil

        if let error = error {
            logging.info("Cancelling login flow with error: \(error.localizedDescription)")
        } else {
            logging.info("Cancelling login flow")
        }

        guard let loginController = loginController else {
            return
        }

        Task { @MainActor in
            cleanup()
            if let error = error {
                loginController.oidcParams.onError(error)
            }
        }
    }

    public func logout() async throws {
        defer {
            logging.xEventId = nil
        }

        let idToken = session.profile?.tokenResponse.idToken

        await session.clear()

        guard let idToken = idToken else {
            logging.debug("Logout called without session")
            return
        }

        logging.debug("Logging user out")

        let logoutEndpoint = issuer.appendingPathComponent("/oauth2/sessions/logout")
        var urlComponents = URLComponents(url: logoutEndpoint, resolvingAgainstBaseURL: false)!
        urlComponents.queryItems = [
            URLQueryItem(name: "id_token_hint", value: idToken),
            URLQueryItem(name: "post_logout_redirect_uri", value: postLogoutURI.absoluteString),
        ]

        guard let url = urlComponents.url else {
            logging.debug("Could not generate /logout url")
            assert(false, "Unable to generate /logout url")
        }

        try await oidcHandlerService.handleCall(url: url)
        logging.info("Logout completed successfully")
    }

    public func isAuthenticated() async throws -> Bool {
        try await refreshTokensIfNeeded()
        return session.profile != nil
    }

    public func getAccessToken() async throws -> String? {
        try await refreshTokensIfNeeded()
        return session.profile?.tokenResponse.accessToken
    }

    private func continueFlow(oidcParams: OidcParams, queryParameters: [String: String]) async {
        if let loginController = loginController, let sessionId = queryParameters["session_id"] {
            do {
                try await loginController.initialize()
            } catch {
                await MainActor.run {
                    cleanup()
                    oidcParams.onError(NativeSDKError.unknownError(source: error))
                }
            }

            return
        }

        if let error = queryParameters["error"], let errorDescription = queryParameters["error_description"] {
            await session.clear()

            await MainActor.run {
                cleanup()
                oidcParams.onError(NativeSDKError.oidcError(
                    error: error,
                    errorDescription: errorDescription.replacingOccurrences(of: "+", with: " ")
                        .removingPercentEncoding ?? errorDescription
                ))
            }
            return
        }

        guard let state = queryParameters["state"] else {
            assert(false, "State missing from response")
        }

        if state != oidcParams.state {
            await MainActor.run {
                cleanup()
                oidcParams.onError(NativeSDKError.invalidCallback(reason: "State param did not matched expected value"))
            }
            return
        }

        guard let code = queryParameters["code"] else {
            assert(false, "Code missing from response")
        }

        do {
            let tokenResponse = try await oidcHandlerService.tokenExchange(
                url: issuer.appendingPathComponent("/oauth2/token"),
                params: TokenExchangeParams(
                    code: code,
                    codeVerifier: oidcParams.codeVerifier,
                    redirectURI: redirectURI.absoluteString,
                    clientId: clientId
                )
            )

            guard let nonce = JWTUtils.parseJWT(tokenResponse.idToken)["nonce"] as? String else {
                logging.debug("Nonce missing from response")
                assert(false, "Nonce missing from response")
            }

            if nonce != oidcParams.nonce {
                logging.debug("Nonce param did not match expected value")
                await MainActor.run {
                    cleanup()
                    oidcParams
                        .onError(NativeSDKError.invalidCallback(reason: "Nonce param did not matched expected value"))
                }
                return
            }

            await session.update(tokenResponse: tokenResponse)

            logging.xEventId = nil
            logging.info("Login successful")
            await MainActor.run {
                cleanup()
                oidcParams.onSuccess()
            }
        } catch {
            logging.error("Login attempt failed", error: error)
            await MainActor.run {
                cleanup()
                oidcParams.onError(NativeSDKError.unknownError(source: error))
            }
        }
    }

    private func refreshTokensIfNeeded() async throws {
        logging.debug("Attempting to refresh token")

        guard let profile = session.profile else {
            logging.debug("Token refresh not possible - session not found")
            return
        }

        guard Date.now >= profile.accessTokenExpiresAt else {
            logging.debug("Token refresh not needed - access token has not expired")
            return
        }

        guard let refreshToken = session.profile?.tokenResponse.refreshToken else {
            logging.info("Cannot refresh token, signing user out due to expired access token")
            await session.clear()
            return
        }

        do {
            let refreshResponse = try await oidcHandlerService.tokenRefresh(
                url: issuer.appendingPathComponent("/oauth2/token"),
                params: TokenRefreshParams(refreshToken: refreshToken, clientId: clientId)
            )

            await session.update(tokenResponse: refreshResponse)
            logging.info("Session refreshed successfully")
            return
        } catch {
            logging.debug("Could not refresh session due to error: \(error.localizedDescription)")
            await session.clear()
        }
    }

    private func cleanup() {
        session.loginInProgress = false
        loginController = nil
    }
}

public struct LoginParameters {
    public init(
        prompt: String? = nil,
        loginHint: String? = nil,
        acrValue: String? = nil,
        scopes: [String]? = nil,
        prefersEphemeralWebBrowserSession: Bool = false,
        audiences: [String]? = nil
    ) {
        self.prompt = prompt
        self.loginHint = loginHint
        self.acrValue = acrValue
        self.scopes = scopes
        self.prefersEphemeralWebBrowserSession = prefersEphemeralWebBrowserSession
        self.audiences = audiences
    }

    let prompt: String?
    let loginHint: String?
    let acrValue: String?
    let scopes: [String]?
    let prefersEphemeralWebBrowserSession: Bool
    let audiences: [String]?
}

public enum SdkMode: String {
    case ios
    case iosMinimal = "ios-minimal"
}

extension Array {
    var nilIfEmpty: [Element]? {
        isEmpty ? nil : self
    }
}

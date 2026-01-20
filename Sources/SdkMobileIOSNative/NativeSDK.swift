import Foundation

public class NativeSDK {
    let issuer: URL
    let clientId: String
    let redirectURI: URL
    let postLogoutURI: URL
    let mode: SdkMode

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
        mode: SdkMode = .ios
    ) {
        self.issuer = issuer
        self.clientId = clientId
        self.redirectURI = redirectURI
        self.postLogoutURI = postLogoutURI
        self.mode = mode

        httpService = HttpService()
        oidcHandlerService = OIDCHandlerService(httpService: httpService)

        session = Session(storage: storage)
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
                sessionId: sessionId
            )
            let loginController = LoginController(
                nativeSDK: self,
                loginHandlerService: loginHandlerService,
                oidcParams: oidcParams
            )

            try await loginController.initialize()
            self.loginController = loginController

            await MainActor.run {
                self.session.loginInProgress = true
            }
        } catch {
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
        let idToken = session.profile?.tokenResponse.idToken

        await session.clear()

        guard let idToken = idToken else {
            return
        }

        let logoutEndpoint = issuer.appendingPathComponent("/oauth2/sessions/logout")
        var urlComponents = URLComponents(url: logoutEndpoint, resolvingAgainstBaseURL: false)!
        urlComponents.queryItems = [
            URLQueryItem(name: "id_token_hint", value: idToken),
            URLQueryItem(name: "post_logout_redirect_uri", value: postLogoutURI.absoluteString),
        ]

        guard let url = urlComponents.url else {
            assert(false, "Unable to generate /logout url")
        }

        try await oidcHandlerService.handleCall(url: url)
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
                assert(false, "Nonce missing from response")
            }

            if nonce != oidcParams.nonce {
                await MainActor.run {
                    cleanup()
                    oidcParams
                        .onError(NativeSDKError.invalidCallback(reason: "Nonce param did not matched expected value"))
                }
                return
            }

            await session.update(tokenResponse: tokenResponse)

            await MainActor.run {
                cleanup()
                oidcParams.onSuccess()
            }
        } catch {
            await MainActor.run {
                cleanup()
                oidcParams.onError(NativeSDKError.unknownError(source: error))
            }
        }
    }

    private func refreshTokensIfNeeded() async throws {
        guard
            let accessTokenExpiresAt = session.profile?.accessTokenExpiresAt,
            Date.now >= accessTokenExpiresAt else {
            return
        }

        guard let refreshToken = session.profile?.tokenResponse.refreshToken else {
            await session.clear()
            return
        }

        do {
            let refreshResponse = try await oidcHandlerService.tokenRefresh(
                url: issuer.appendingPathComponent("/oauth2/token"),
                params: TokenRefreshParams(refreshToken: refreshToken, clientId: clientId)
            )

            await session.update(tokenResponse: refreshResponse)
            return
        } catch {
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

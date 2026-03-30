import AuthenticationServices
import Foundation

public class WebauthnHandler: NSObject, ASAuthorizationControllerDelegate,
    ASAuthorizationControllerPresentationContextProviding {
    var onFinish: (([String: Any]) async -> Void)?
    var onError: ((Error?) async -> Void)?

    var controller: ASAuthorizationController?

    override public init() {}

    func enroll(
        enrollOptions: WebauthnEnrollWidget.EnrollOptions,
        onFinish: @escaping (([String: Any]) async -> Void),
        onError: @escaping ((Error?) async -> Void)
    ) {
        guard let userId = enrollOptions.user.id.base64URLDecode() else {
            Task {
                await onError(nil)
            }
            return
        }
        guard let challenge = enrollOptions.challenge.base64URLDecode() else {
            Task {
                await onError(nil)
            }
            return
        }

        let request: ASAuthorizationRequest?

        switch enrollOptions.authenticatorSelection.authenticatorAttachment {
        case "platform", nil:
            let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(
                relyingPartyIdentifier: enrollOptions.rp.id
            )

            request = provider.createCredentialRegistrationRequest(
                challenge: challenge,
                name: enrollOptions.user.name,
                userID: userId
            )
        case "cross-platform":
            let provider = ASAuthorizationSecurityKeyPublicKeyCredentialProvider(
                relyingPartyIdentifier: enrollOptions.rp.id
            )

            request = provider.createCredentialRegistrationRequest(
                challenge: challenge,
                displayName: enrollOptions.user.displayName,
                name: enrollOptions.user.name,
                userID: userId
            )
        default:
            request = nil
        }

        guard let request = request else {
            Task {
                await onError(nil)
            }
            return
        }

        if let typedRequest = request as? ASAuthorizationPublicKeyCredentialRegistrationRequest {
            typedRequest
                .attestationPreference = ASAuthorizationPublicKeyCredentialAttestationKind(enrollOptions.attestation)
            typedRequest
                .userVerificationPreference =
                ASAuthorizationPublicKeyCredentialUserVerificationPreference(rawValue: enrollOptions
                    .authenticatorSelection.userVerification) ?? .preferred
        }

        // Platform
        if let typedRequest = request as? ASAuthorizationPlatformPublicKeyCredentialRegistrationRequest {
            if #available(iOS 17.4, *) {
                typedRequest.excludedCredentials = enrollOptions.excludeCredentials.compactMap { excludeCredential in
                    if let id = excludeCredential.id.base64URLDecode() {
                        return ASAuthorizationPlatformPublicKeyCredentialDescriptor(credentialID: id)
                    }
                    return nil
                }
            }
        }

        // Security key
        if let typedRequest = request as? ASAuthorizationSecurityKeyPublicKeyCredentialRegistrationRequest {
            typedRequest.credentialParameters = enrollOptions.pubKeyCredParams.map { param in
                ASAuthorizationPublicKeyCredentialParameters(algorithm: ASCOSEAlgorithmIdentifier(param.alg))
            }

            typedRequest
                .residentKeyPreference = ASAuthorizationPublicKeyCredentialResidentKeyPreference(rawValue: enrollOptions
                    .authenticatorSelection.residentKey)

            if #available(iOS 17.4, *) {
                typedRequest.excludedCredentials = enrollOptions.excludeCredentials.compactMap { excludeCredential in
                    if let id = excludeCredential.id.base64URLDecode() {
                        return ASAuthorizationSecurityKeyPublicKeyCredentialDescriptor(
                            credentialID: id,
                            transports: excludeCredential.transports.map {
                                ASAuthorizationSecurityKeyPublicKeyCredentialDescriptor.Transport(rawValue: $0)
                            }
                        )
                    }
                    return nil
                }
            }
        }

        self.onFinish = onFinish
        self.onError = onError

        controller = ASAuthorizationController(authorizationRequests: [request])
        controller?.delegate = self
        controller?.presentationContextProvider = self
        controller?.performRequests()
    }

    func authenticate(
        assertionOptions: WebauthnLoginWidget.AssertionOptions,
        onFinish: @escaping (([String: Any]) async -> Void),
        onError: @escaping ((Error?) async -> Void)
    ) {
        guard let challenge = assertionOptions.challenge.base64URLDecode() else {
            Task {
                await onError(nil)
            }
            return
        }

        let userVerificationPreference =
            ASAuthorizationPublicKeyCredentialUserVerificationPreference(rawValue: assertionOptions.userVerification) ??
            .preferred

        let platformProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(
            relyingPartyIdentifier: assertionOptions.rpId
        )

        let platformRequest = platformProvider.createCredentialAssertionRequest(challenge: challenge)
        platformRequest.userVerificationPreference = userVerificationPreference
        platformRequest.allowedCredentials = assertionOptions.allowCredentials.compactMap { allowCredential in
            if let id = allowCredential.id.base64URLDecode() {
                return ASAuthorizationPlatformPublicKeyCredentialDescriptor(credentialID: id)
            }
            return nil
        }

        let securityKeyProvider = ASAuthorizationSecurityKeyPublicKeyCredentialProvider(
            relyingPartyIdentifier: assertionOptions.rpId
        )

        let securityKeyRequest = securityKeyProvider.createCredentialAssertionRequest(challenge: challenge)
        securityKeyRequest.userVerificationPreference = userVerificationPreference
        securityKeyRequest.allowedCredentials = assertionOptions.allowCredentials.compactMap { excludeCredential in
            if let id = excludeCredential.id.base64URLDecode() {
                return ASAuthorizationSecurityKeyPublicKeyCredentialDescriptor(
                    credentialID: id,
                    transports: excludeCredential.transports.map {
                        ASAuthorizationSecurityKeyPublicKeyCredentialDescriptor.Transport(rawValue: $0)
                    }
                )
            }
            return nil
        }

        self.onFinish = onFinish
        self.onError = onError

        controller = ASAuthorizationController(authorizationRequests: [platformRequest, securityKeyRequest])
        controller?.delegate = self
        controller?.presentationContextProvider = self
        controller?.performRequests()
    }

    public func authorizationController(
        controller _: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        if let credential = authorization.credential as? ASAuthorizationPublicKeyCredentialRegistration {
            let response: [String: Any] = [
                "id": credential.credentialID.base64URLEncodedString(),
                "rawId": credential.credentialID.base64URLEncodedString(),
                "type": "public-key",
                "response": [
                    "clientDataJSON": credential.rawClientDataJSON.base64URLEncodedString(),
                    "attestationObject": credential.rawAttestationObject.map { $0.base64URLEncodedString() } ?? "",
                ],
            ]

            Task {
                await onFinish?(response)
            }
        } else if let credential = authorization.credential as? ASAuthorizationPublicKeyCredentialAssertion {
            // Note: userID can be nil for security keys
            let response: [String: Any] = [
                "id": credential.credentialID.base64URLEncodedString(),
                "rawId": credential.credentialID.base64URLEncodedString(),
                "type": "public-key",
                "response": [
                    "clientDataJSON": credential.rawClientDataJSON.base64URLEncodedString(),
                    "authenticatorData": credential.rawAuthenticatorData.base64URLEncodedString(),
                    "signature": credential.signature.base64URLEncodedString(),
                    "userHandle": credential.userID?.base64URLEncodedString(),
                ],
            ]

            Task {
                await onFinish?(response)
            }
        } else {
            Task {
                await onError?(nil)
            }
        }
    }

    public func authorizationController(controller _: ASAuthorizationController, didCompleteWithError error: Error) {
        Task {
            await onError?(error)
        }
    }

    public func presentationAnchor(for _: ASAuthorizationController) -> ASPresentationAnchor {
        return UIApplication.shared.windows.first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}

private extension String {
    func base64URLDecode() -> Data? {
        var base64 = replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }

        guard let data = Data(base64Encoded: base64) else {
            return nil
        }

        return data
    }
}

import Foundation
import AuthenticationServices

class WebauthnHandler: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {

    var onFinish: (([String: Any]) async -> Void)?
    var onError: ((Error?) async -> Void)?

    public override init() {
        self.onFinish = nil
    }

    func enroll(
        enrollOptions: WebauthnEnrollWidget.EnrollOptions,
        onFinish: @escaping (([String: Any]) async -> Void),
        onError: @escaping ((Error?) async -> Void),
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
        let displayName = enrollOptions.user.displayName

        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(
            relyingPartyIdentifier: enrollOptions.rp.id
        )

        let request = provider.createCredentialRegistrationRequest(
            challenge: challenge,
            name: displayName,
            userID: userId
        )

        request.attestationPreference = ASAuthorizationPublicKeyCredentialAttestationKind(enrollOptions.attestation)
        request.userVerificationPreference = ASAuthorizationPublicKeyCredentialUserVerificationPreference(rawValue: enrollOptions.authenticatorSelection.userVerification) ?? .preferred

        if #available(iOS 17.4, *) {
            request.excludedCredentials = enrollOptions.excludeCredentials.compactMap({ excludeCredential in
                if let id = excludeCredential.id.base64URLDecode() {
                    return ASAuthorizationPlatformPublicKeyCredentialDescriptor(credentialID: id)
                }
                return nil
            })
        }

        self.onFinish = onFinish
        self.onError = onError

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    func authenticate(
        assertionOptions: WebauthnLoginWidget.AssertionOptions,
        onFinish: @escaping (([String: Any]) async -> Void),
        onError: @escaping ((Error?) async -> Void),
    ) {
        guard let challenge = assertionOptions.challenge.base64URLDecode() else {
            Task {
                await onError(nil)
            }
            return
        }

        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(
            relyingPartyIdentifier: assertionOptions.rpId
        )

        let request = provider.createCredentialAssertionRequest(challenge: challenge)

        request.userVerificationPreference = ASAuthorizationPublicKeyCredentialUserVerificationPreference(rawValue: assertionOptions.userVerification) ?? .preferred
        request.allowedCredentials = assertionOptions.allowCredentials.compactMap({ allowCredential in
            if let id = allowCredential.id.base64URLDecode() { // TODO URL??
                return ASAuthorizationPlatformPublicKeyCredentialDescriptor(credentialID: id)
            }
            return nil
        })

        self.onFinish = onFinish
        self.onError = onError

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    public func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let credential = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialRegistration {
            let response: [String: Any] = [
                "id": credential.credentialID.base64URLEncodedString(),
                "rawId": credential.credentialID.base64URLEncodedString(),
                "type": "public-key",
                "response": [
                    "clientDataJSON": credential.rawClientDataJSON.base64URLEncodedString(),
                    "attestationObject": credential.rawAttestationObject.map { $0.base64URLEncodedString() } ?? ""
                ]
            ]

            Task {
                await onFinish?(response)
            }
        } else if let credential = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialAssertion {
            let response: [String: Any] = [
                "id": credential.credentialID.base64URLEncodedString(),
                "rawId": credential.credentialID.base64URLEncodedString(),
                "type": "public-key",
                "response": [
                    "clientDataJSON": credential.rawClientDataJSON.base64URLEncodedString(),
                    "authenticatorData": credential.rawAuthenticatorData.base64URLEncodedString(),
                    "signature": credential.signature.base64URLEncodedString(),
                    "userHandle": credential.userID.base64URLEncodedString()
                ]
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

    public func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        Task {
            await onError?(error)
        }
      }

    public func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
      return UIApplication.shared.windows.first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}

private extension String {
    func base64URLDecode() -> Data? {
        var base64 = self
            .replacingOccurrences(of: "-", with: "+")
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

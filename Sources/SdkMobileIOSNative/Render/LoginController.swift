import AuthenticationServices
import SwiftUI

public class LoginController: ObservableObject {
    @Published var screen: Screen?
    @Published var formModel: FormModel?
    @Published public var processing: Bool = false

    var nativeSDK: NativeSDK
    var loginHandlerService: LoginHandlerService
    var oidcParams: OidcParams

    let authWebView = AuthWebView()

    init(nativeSDK: NativeSDK, loginHandlerService: LoginHandlerService, oidcParams: OidcParams) {
        self.nativeSDK = nativeSDK
        self.loginHandlerService = loginHandlerService
        self.oidcParams = oidcParams
    }

    func initialize() async throws {
        try await updateScreen(screen: await loginHandlerService.initCall())
    }

    @MainActor
    func updateScreen(screen: Screen) async {
        DispatchQueue.main.async {
            self.processing = false
        }

        if let finalizeUrl = screen.finalizeUrl {
            await nativeSDK.continueFlow(uri: URL(string: finalizeUrl)!)
            return
        }

        if let hostedUrl = screen.hostedUrl, screen.forms == nil, screen.messages == nil {
            authWebView.open(
                hostedURL: URL(string: hostedUrl)!,
                customURIScheme: nativeSDK.redirectURI.scheme!,
                prefersEphemeralWebBrowserSession: oidcParams.prefersEphemeralWebBrowserSession
            ) { redirectURLScheme in
                Task {
                    await self.nativeSDK.continueFlow(uri: redirectURLScheme)
                }
            } errorCallback: { error in
                if let error = error as? NSError {
                    if error.domain == ASWebAuthenticationSessionError.errorDomain,
                       error.code == ASWebAuthenticationSessionError.Code.canceledLogin.rawValue {
                        self.nativeSDK.cancelFlow(error: .hostedFlowCanceled)
                        return
                    }
                }

                self.nativeSDK.cancelFlow(error: .unknownError(source: error))
            }
            return
        }

        if let forms = screen.forms {
            self.screen = screen
            formModel = FormModel(formWidgets: forms)
        } else if let messages = screen.messages {
            self.screen?.messages = screen.messages
        }
    }

    @MainActor
    func clearGlobalErrorMessage() {
        switch screen?.messages {
        case .global:
            screen?.messages = nil
        default:
            break
        }
    }

    public func bindingForWidget<T>(formId: String, widgetId: String, defaultValue: T) -> Binding<T> where T: Codable {
        return Binding(get: { [self] in
            return formModel?.forms[formId]?[widgetId] as? T ?? defaultValue
        }, set: { [self] in
            formModel?.setWidgetValue(formId: formId, widgetId: widgetId, value: $0)
        })
    }

    public func triggerFallback() async {
        await updateScreen(screen: Screen(
            screen: nil,
            branding: nil,
            hostedUrl: screen?.hostedUrl,
            finalizeUrl: nil,
            forms: nil,
            layout: nil,
            messages: nil
        ))
    }

    public func errorMessage(formId: String, widgetId: String) -> String? {
        switch screen?.messages {
        case let .form(messages):
            return messages[formId]?[widgetId]?.text
        default:
            return nil
        }
    }

    public func submit(formId: String) async {
        await MainActor.run {
            processing = true
        }

        let formData = formModel?.formRequestData(formId: formId)

        await submit(formId: formId, formData: formData)
    }

    func submit(formId: String, formData: [String: Any]?) async {
        do {
            try await updateScreen(screen: loginHandlerService.submitForm(formId: formId, body: formData ?? [:]))
        } catch NativeSDKError.sessionExpired {
            nativeSDK.cancelFlow(error: NativeSDKError.sessionExpired)
        } catch {
            await triggerFallback()
        }
    }
}

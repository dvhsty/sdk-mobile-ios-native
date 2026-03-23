import SwiftUI

public struct LoginView<LayoutView: View>: View {
    @ObservedObject var loginController: LoginController

    @ViewBuilder var layoutView: (_ loginController: LoginController,
                                  _ screen: String,
                                  _ forms: [FormWidget],
                                  _ layout: Layout) -> LayoutView

    var showAlert: Bool {
        return switch loginController.screen?.messages {
        case .global:
            true
        default:
            false
        }
    }

    var alertText: String {
        return switch loginController.screen?.messages {
        case let .global(message):
            message.text
        default:
            ""
        }
    }

    public init(nativeSDK: NativeSDK, @ViewBuilder layout: @escaping (_ loginController: LoginController,
                                                                      _ screen: String,
                                                                      _ forms: [FormWidget],
                                                                      _ layout: Layout) -> LayoutView) {
        guard let loginController = nativeSDK.loginController else {
            assert(false, "No login session in progress")
        }

        self.loginController = loginController
        layoutView = layout
    }

    public var body: some View {
        if let screen = loginController.screen?.screen,
           let forms = loginController.screen?.forms,
           let layout = loginController.screen?.layout {
            layoutView(loginController, screen, forms, layout)
                .disabled(loginController.processing)
                .environmentObject(loginController)
                .alert(alertText, isPresented: .constant(showAlert)) {
                    Button("OK", role: .cancel) {
                        loginController.clearGlobalErrorMessage()
                    }
                }
        }
    }
}

public extension LoginView where LayoutView == LoginLayoutView<LoginWidgetView> {
    init(nativeSDK: NativeSDK) {
        self.init(nativeSDK: nativeSDK) { _, screen, forms, layout in
            LoginLayoutView(screen: screen, forms: forms, layout: layout)
        }
    }
}

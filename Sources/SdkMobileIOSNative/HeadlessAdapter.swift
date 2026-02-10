import Combine
import Foundation

public class HeadlessAdapter {
    var nativeSDK: NativeSDK
    private var loginController: LoginController

    private var delegate: HeadlessAdapterDelegate

    private var cancellables = Set<AnyCancellable>()

    public init(nativeSDK: NativeSDK, delegate: HeadlessAdapterDelegate) {
        precondition(
            nativeSDK.loginController != nil,
            "No login session started. Make sure to call `NativeSDK.login()` first."
        )

        self.nativeSDK = nativeSDK
        self.delegate = delegate
        loginController = nativeSDK.loginController!

        loginController.$screen
            .sink { [self] _ in
                let currentScreen = self.getScreen()
                DispatchQueue.main.async {
                    if !nativeSDK.session.loginInProgress {
                        return
                    }

                    if let newScreen = self.getScreen() {
                        if
                            currentScreen?.screen == newScreen.screen,
                            currentScreen?.forms == newScreen.forms,
                            currentScreen?.layout == newScreen.layout,
                            currentScreen?.messages != newScreen.messages {
                            delegate.refreshScreen(screen: newScreen)
                            return
                        }
                        delegate.renderScreen(screen: newScreen)
                    }
                }
            }
            .store(in: &cancellables)
    }

    public func initialize() {
        let screen = getScreen()
        precondition(screen == nil, "Expected screen to be available when HeadlessAdapter.initialize() is called.")
        delegate.renderScreen(screen: screen!)
    }

    public func getScreen() -> Screen? {
        return loginController.screen
    }

    public func errorMessage(formId: String, widgetId: String) -> String? {
        return loginController.errorMessage(formId: formId, widgetId: widgetId)
    }

    public func submit(formId: String, data: [String: Any]?) async {
        await loginController.submit(formId: formId, formData: data)
    }

    func submitForm(formId: String) async {
        let formData = loginController.formModel?.formRequestData(formId: formId)
        await submit(formId: formId, data: formData)
    }

    public func closeFlow() async throws {
        try await loginController.closeFlow()
    }
}

public protocol HeadlessAdapterDelegate: AnyObject {
    func renderScreen(screen: Screen)
    func refreshScreen(screen: Screen)
}

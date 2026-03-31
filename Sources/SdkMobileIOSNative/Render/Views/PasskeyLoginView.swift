import SwiftUI

struct PasskeyLoginView: View {
    @EnvironmentObject var loginController: LoginController

    @State var handler = WebauthnHandler()
    @State var errorMessage: String?

    @State var autofillHandler = WebauthnHandler()

    // periphery:ignore
    let screen: String
    let formId: String
    // periphery:ignore
    let widgetId: String

    let widget: PasskeyLoginWidget

    init(screen: String, formId: String, widgetId: String, widget: PasskeyLoginWidget) {
        self.screen = screen
        self.formId = formId
        self.widgetId = widgetId
        self.widget = widget
    }

    var body: some View {
        VStack {
            let button = Button {
                Task {
                    if #available(iOS 16.0, *) {
                        autofillHandler.close()
                    }

                    handler.authenticate(assertionOptions: widget.assertionOptions) { result in
                        loginController.setWidgetData(formId: formId, widgetId: widgetId, value: result)
                        await loginController.submit(formId: formId)
                    } onError: { err in
                        errorMessage = err?.localizedDescription
                        autofill()
                    }
                }
            } label: { Text(widget.label) }

            switch widget.render?.type {
            case "button":
                button
                    .buttonStyle(.borderedProminent)

            case "link":
                button

            default:
                FallbackTriggerView()
            }

            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
            }
        }
        .onAppear {
            autofill()
        }
        .onDisappear {
            if #available(iOS 16.0, *) {
                autofillHandler.close()
            }
        }
    }

    func autofill() {
        if #available(iOS 16.0, *) {
            autofillHandler.autofill(assertionOptions: widget.assertionOptions) { result in
                loginController.setWidgetData(formId: formId, widgetId: widgetId, value: result)
                await loginController.submit(formId: formId)
            } onError: { _ in
            }
        }
    }
}

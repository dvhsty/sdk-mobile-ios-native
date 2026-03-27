import SwiftUI

struct WebauthnLoginView: View {
    @EnvironmentObject var loginController: LoginController

    @State var handler = WebauthnHandler()
    @State var errorMessage: String?

    // periphery:ignore
    let screen: String
    let formId: String
    // periphery:ignore
    let widgetId: String

    let widget: WebauthnLoginWidget

    init(screen: String, formId: String, widgetId: String, widget: WebauthnLoginWidget) {
        self.screen = screen
        self.formId = formId
        self.widgetId = widgetId
        self.widget = widget
    }

    var body: some View {
        VStack {
            let button = Button {
                Task {
                    handler.authenticate(assertionOptions: widget.assertionOptions) { result in
                        loginController.setWidgetData(formId: formId, widgetId: widgetId, value: result)
                        await loginController.submit(formId: formId)
                    } onError: { err in
                        errorMessage = err?.localizedDescription
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
    }
}

import Foundation
import SwiftUI

public struct LoginWidgetView: View {
    @EnvironmentObject var loginController: LoginController
    // periphery:ignore
    let screen: String
    // periphery:ignore
    let formId: String
    // periphery:ignore
    let widgetId: String

    // periphery:ignore
    let widget: Widget

    public init(screen: String, formId: String, widgetId: String, widget: Widget) {
        self.screen = screen
        self.formId = formId
        self.widgetId = widgetId
        self.widget = widget
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch widget {
            case let .submit(widget):
                SubmitView(screen: screen, formId: formId, widgetId: widgetId, widget: widget)
            case let .staticWidget(widget):
                StaticView(screen: screen, formId: formId, widgetId: widgetId, widget: widget)
            case let .input(widget):
                InputView(screen: screen, formId: formId, widgetId: widgetId, widget: widget)
            case let .password(widget):
                PasswordWiew(screen: screen, formId: formId, widgetId: widgetId, widget: widget)
            case let .select(widget):
                SelectView(screen: screen, formId: formId, widgetId: widgetId, widget: widget)
            case let .multiselect(widget):
                MultiSelectView(screen: screen, formId: formId, widgetId: widgetId, widget: widget)
            case let .checkbox(widget):
                CheckboxView(screen: screen, formId: formId, widgetId: widgetId, widget: widget)
            case let .passcode(widget):
                PasscodeView(screen: screen, formId: formId, widgetId: widgetId, widget: widget)
            case let .phone(widget):
                PhoneView(screen: screen, formId: formId, widgetId: widgetId, widget: widget)
            case let .date(widget):
                DateView(screen: screen, formId: formId, widgetId: widgetId, widget: widget)
            case let .close(widget):
                CloseView(widget: widget)
            case let .passkeyEnroll(widget):
                PasskeyEnrollView(screen: screen, formId: formId, widgetId: widgetId, widget: widget)
            case let .passkeyLogin(widget):
                PasskeyLoginView(screen: screen, formId: formId, widgetId: widgetId, widget: widget)
            default:
                FallbackTriggerView()
            }

            if let error = loginController.errorMessage(formId: formId, widgetId: widgetId) {
                ErrorView(error: error)
            }
        }
        .disabled(widget.readonly)
    }

    struct ErrorView: View {
        var error: String

        var body: some View {
            Text(error)
                .foregroundColor(.red)
        }
    }
}

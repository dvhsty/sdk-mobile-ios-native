import SwiftUI

struct CloseView: View {
    @EnvironmentObject var loginController: LoginController

    let widget: CloseWidget

    init(widget: CloseWidget) {
        self.widget = widget
    }

    var body: some View {
        let button = Button(widget.label!) {
            Task {
                await try loginController.closeFlow()
            }
        }

        switch widget.render?.type {
        case "button":
            button.buttonStyle(.borderedProminent)
        case "link":
            button
        default:
            FallbackTriggerView()
        }
    }
}

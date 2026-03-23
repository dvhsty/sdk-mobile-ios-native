import Foundation
import SwiftUI

public struct LoginLayoutView<WidgetView: View>: View {
    let screen: String
    let forms: [FormWidget]

    let layout: Layout

    @ViewBuilder let widgetView: (
        _ screen: String,
        _ formId: String,
        _ widgetId: String,
        _ widget: Widget
    ) -> WidgetView

    public init(
        screen: String,
        forms: [FormWidget],
        layout: Layout,
        @ViewBuilder widgetView: @escaping (
            _ screen: String,
            _ formId: String,
            _ widgetId: String,
            _ widget: Widget
        ) -> WidgetView
    ) {
        self.screen = screen
        self.forms = forms
        self.layout = layout

        self.widgetView = widgetView
    }

    public var body: some View {
        Group {
            switch layout {
            case let .horizontal(layout):
                horizontalLayout(layout)
            case let .vertical(layout):
                verticalLayout(layout)
            case let .widget(layout):
                widgetLayout(layout)
            default:
                FallbackTriggerView()
            }
        }
    }

    func horizontalLayout(_ layout: SingleLayout) -> some View {
        HStack {
            ForEach(Array(layout.items.enumerated()), id: \.offset) { _, element in
                LoginLayoutView(screen: screen, forms: forms, layout: element, widgetView: widgetView)
            }
        }
    }

    func verticalLayout(_ layout: SingleLayout) -> some View {
        VStack {
            ForEach(Array(layout.items.enumerated()), id: \.offset) { _, element in
                LoginLayoutView(screen: screen, forms: forms, layout: element, widgetView: widgetView)
            }
        }
    }

    @ViewBuilder
    func widgetLayout(_ layout: WidgetLayout) -> some View {
        let widget = forms
            .first(where: { $0.id == layout.formId })?.widgets
            .first(where: { $0.id == layout.widgetId })

        if let widget = widget {
            widgetView(screen, layout.formId, layout.widgetId, widget)
        } else {
            FallbackTriggerView()
        }
    }
}

public extension LoginLayoutView where WidgetView == LoginWidgetView {
    init(
        screen: String,
        forms: [FormWidget],
        layout: Layout
    ) {
        self.init(screen: screen, forms: forms, layout: layout) { screen, formId, widgetId, widget in
            LoginWidgetView(screen: screen, formId: formId, widgetId: widgetId, widget: widget)
        }
    }
}

import SdkMobileIOSNative
import SwiftUI

struct DateView: View {
    // periphery:ignore
    let screen: String
    // periphery:ignore
    let formId: String
    let widgetId: String

    let widget: DateWidget

    @EnvironmentObject var loginController: LoginController

    @State private var day: String = ""
    @State private var month: String = ""
    @State private var year: String = ""
    @State private var isDatePickerVisible: Bool = false

    var body: some View {
        if widget.render?.type == "native" {
            HStack {
                Text(widget.label ?? "")
                Spacer()

                if isDatePickerVisible {
                    DatePicker(
                        "",
                        selection: Binding(
                            get: { convertStringToDate(loginController.bindingForWidget(
                                formId: formId,
                                widgetId: widgetId,
                                defaultValue: ""
                            ).wrappedValue) ?? Date() },
                            set: { newDate in
                                if newDate != nil {
                                    loginController.bindingForWidget(
                                        formId: formId,
                                        widgetId: widgetId,
                                        defaultValue: ""
                                    )
                                    .wrappedValue = convertDateToString(newDate)
                                }
                            }
                        ),
                        displayedComponents: .date
                    )
                    .datePickerStyle(CompactDatePickerStyle())
                    .environment(\.locale, Locale(identifier: Locale.preferredLanguages[0]))

                    Button(action: {
                        loginController.bindingForWidget(formId: formId, widgetId: widgetId, defaultValue: "")
                            .wrappedValue = nil
                        isDatePickerVisible.toggle()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                } else {
                    Button(action: { isDatePickerVisible.toggle() }) {
                        HStack {
                            Text(widget.label ?? "")
                                .foregroundColor(.gray)

                            Image(systemName: "calendar")
                                .foregroundColor(.blue)
                        }
                        .padding(6)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        } else if widget.render?.type == "fieldSet" {
            HStack {
                Text(widget.label ?? "")
            }

            HStack {
                let dateOrder = getLocalizedDateOrder()
                ForEach(dateOrder, id: \.self) { component in
                    if component == "day" {
                        TextField(
                            getLocalizedDateNames("d"),
                            text: $day
                        )
                        .keyboardType(.numberPad)
                        .onChange(of: day) { _ in updateDateBinding() }
                    } else if component == "month" {
                        TextField(
                            getLocalizedDateNames("MMMM"),
                            text: $month
                        )
                        .keyboardType(.numberPad)
                        .onChange(of: month) { _ in updateDateBinding() }
                    } else if component == "year" {
                        TextField(
                            getLocalizedDateNames("y"),
                            text: $year
                        )
                        .keyboardType(.numberPad)
                        .onChange(of: year) { _ in updateDateBinding() }
                    }
                }
            }.onAppear {
                loadExistingDate()
            }

        } else {
            FallbackTriggerView()
        }
    }

    private func convertDateToString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        formatter.locale = Locale.current
        return formatter.string(from: date)
    }

    private func getLocalizedDateOrder() -> [String] {
        let locale = Locale(identifier: Locale.preferredLanguages[0])
        let format = DateFormatter.dateFormat(fromTemplate: "yMd", options: 0, locale: locale) ?? "yyyy-MM-dd"

        let components = [("year", "y"), ("month", "M"), ("day", "d")]

        return components
            .compactMap { name, symbol -> (String, Int)? in
                if let index = format.firstIndex(of: Character(symbol)) {
                    return (name, format.distance(from: format.startIndex, to: index))
                }
                return nil
            }
            .sorted { $0.1 < $1.1 }
            .map { $0.0 }
    }

    private func loadExistingDate() {
        let dateString = loginController.bindingForWidget(formId: formId, widgetId: widgetId, defaultValue: "")
            .wrappedValue ?? ""
        let components = dateString.split(separator: "-").map(String.init)

        if components.count == 3 {
            year = components[0]
            month = components[1]
            day = components[2]
        }
    }

    private func updateDateBinding() {
        var formattedDate: String? = "\(year)-\(month)-\(day)"
        if year.isEmpty, month.isEmpty, day.isEmpty {
            formattedDate = nil
        }
        loginController.bindingForWidget(formId: formId, widgetId: widgetId, defaultValue: "")
            .wrappedValue = formattedDate
    }

    private func getLocalizedDateNames(_ template: String) -> String {
        let locale = Locale(identifier: Locale.preferredLanguages[0])
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter.string(from: Date())
    }

    private func convertStringToDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        formatter.locale = Locale.current
        return formatter.date(from: dateString)
    }
}

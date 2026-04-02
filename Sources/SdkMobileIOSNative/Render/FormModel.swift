import SwiftUI

struct FormModel {
    var forms: [String: [String: Any]] = [:]
    var readonlyFormWidgets: [String: [String]] = [:]

    init(formWidgets: [FormWidget]) {
        for formWidget in formWidgets {
            for widget in formWidget.widgets {
                if let value = widget.value {
                    setWidgetValue(formId: formWidget.id, widgetId: widget.id, value: value)
                }

                if widget.readonly {
                    var ids = readonlyFormWidgets[formWidget.id, default: []]
                    ids.append(widget.id)
                    readonlyFormWidgets[formWidget.id] = ids
                }
            }
        }
    }

    func formRequestData(formId: String) -> [String: Any]? {
        guard let formData = forms[formId] else {
            return nil
        }

        var requestData: [String: Any] = [:]
        let readonlyIds = readonlyFormWidgets[formId, default: []]

        for (key, value) in formData {
            if readonlyIds.contains(key) {
                continue
            }

            if value == nil || (value as? String) == "" {
                continue
            }

            let keySegments = key.components(separatedBy: ".")
            requestData = buildRequestData(value: value, dict: requestData, keyPath: Array(keySegments.reversed()))
        }

        return requestData
    }

    mutating func setWidgetValue(formId: String, widgetId: String, value: Any) {
        if forms[formId] == nil {
            forms[formId] = [:]
        }
        forms[formId]![widgetId] = value
    }

    private func buildRequestData(value: Any, dict: [String: Any], keyPath: [String]) -> [String: Any] {
        guard let key = keyPath.last else {
            return dict
        }

        var dict = dict
        if keyPath.count > 1 {
            let defaultDict: [String: Any] = [:]
            // swiftlint:disable:next force_cast
            let subDict = dict[key, default: defaultDict] as! [String: Any]
            let newSubDict = buildRequestData(value: value, dict: subDict, keyPath: Array(keyPath.dropLast()))
            dict[key] = newSubDict
            return dict
        }

        dict[key] = value
        return dict
    }
}

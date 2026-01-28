import Foundation

public struct FormWidget: Decodable, Equatable {
    public let id: String
    public let widgets: [Widget]
}

public struct SubmitWidget: Decodable, Equatable {
    public let id: String
    public let label: String
    public let render: Render?

    public struct Render: Decodable, Equatable {
        public let type: String
        public let textColor: String?
        public let bgColor: String?
        public let hint: SubmitWidgetHint?

        public struct SubmitWidgetHint: Decodable, Equatable {
            public let icon: String?
            public let variant: String?
        }
    }
}

public struct StaticWidget: Decodable, Equatable {
    public let id: String
    public let value: String

    public let render: Render?

    public struct Render: Decodable, Equatable {
        public let type: String
    }
}

public struct InputWidget: Decodable, Equatable {
    public let id: String
    public let label: String
    public let value: String?
    public let readonly: Bool

    public let autocomplete: String?
    public let inputmode: String?

    public let validator: Validator

    public struct Validator: Decodable, Equatable {
        public let minLength: Int?
        public let maxLength: Int?
        public let regex: String?
        public let required: Bool
    }
}

public struct CheckboxWidget: Decodable, Equatable {
    public let id: String
    public let label: String
    public let value: Bool
    public let readonly: Bool

    public let validator: Validator?
    public let render: Render?

    public struct Validator: Decodable, Equatable {
        public let required: Bool
    }

    public struct Render: Decodable, Equatable {
        public let type: String
        public let labelType: String
    }
}

public struct PasswordWidget: Decodable, Equatable {
    public let id: String
    public let label: String
    public let qualityIndicator: Bool

    public let validator: Validator?

    public struct Validator: Decodable, Equatable {
        public let minLength: Int?
        public let maxNumericCharacterSequences: Int?
        public let maxRepeatedCharacters: Int?
        public let mustContain: [String]?
    }
}

public struct SelectWidget: Decodable, Equatable {
    public let id: String
    public let label: String?
    public let value: String?
    public let readonly: Bool

    public let render: Render?
    public let options: [Option]
    public let validator: Validator

    public struct Validator: Decodable, Equatable {
        public let required: Bool
    }

    public struct Option: Decodable, Equatable, Hashable {
        public let type: String
        public let label: String?
        public let value: String?
        public let options: [Option]?
    }

    public struct Render: Decodable, Equatable {
        public let type: String
    }
}

public struct MultiSelectWidget: Decodable, Equatable {
    public let id: String
    public let label: String
    public let value: [String?]
    public let readonly: Bool

    public let options: [Option]
    public let validator: Validator?

    public struct Validator: Decodable, Equatable {
        public let minSelectable: Int
        public let maxSelectable: Int
    }

    public struct Option: Decodable, Equatable, Hashable {
        public let type: String
        public let label: String
        public let value: String
        public let options: [Option]?
    }
}

public struct PasscodeWidget: Decodable, Equatable {
    public let id: String
    public let label: String

    public let validator: Validator?

    public struct Validator: Decodable, Equatable {
        public let length: Int?
    }
}

public struct PhoneWidget: Decodable, Equatable {
    public let id: String
    public let label: String
    public let readonly: Bool
    public let value: String?

    public let validator: Validator?

    public struct Validator: Decodable, Equatable {
        public let required: Bool?
    }
}

public struct DateWidget: Decodable, Equatable {
    public let id: String
    public let label: String?
    public let placeholder: String?
    public let readonly: Bool
    public let value: String?

    public let render: Render?
    public let validator: Validator?

    public struct Render: Decodable, Equatable {
        public let type: String
    }

    public struct Validator: Decodable, Equatable {
        public let required: Bool?
        public let notBefore: String?
        public let notAfter: String?
    }
}

public struct CloseWidget: Decodable, Equatable {
    public let id: String
    public let label: String?
    public let render: Render?

    public struct Render: Decodable, Equatable {
        public let type: String
    }
}

public enum Widget {
    case form(FormWidget)
    case submit(SubmitWidget)

    case staticWidget(StaticWidget)
    case input(InputWidget)
    case checkbox(CheckboxWidget)
    case password(PasswordWidget)
    case select(SelectWidget)
    case multiselect(MultiSelectWidget)
    case passcode(PasscodeWidget)
    case phone(PhoneWidget)
    case date(DateWidget)
    case close(CloseWidget)
}

extension Widget: Decodable, Equatable {
    enum CodingKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "form":
            self = try .form(FormWidget(from: decoder))
        case "submit":
            self = try .submit(SubmitWidget(from: decoder))
        case "static":
            self = try .staticWidget(StaticWidget(from: decoder))
        case "input":
            self = try .input(InputWidget(from: decoder))
        case "checkbox":
            self = try .checkbox(CheckboxWidget(from: decoder))
        case "password":
            self = try .password(PasswordWidget(from: decoder))
        case "select":
            self = try .select(SelectWidget(from: decoder))
        case "multiSelect":
            self = try .multiselect(MultiSelectWidget(from: decoder))
        case "passcode":
            self = try .passcode(PasscodeWidget(from: decoder))
        case "phone":
            self = try .phone(PhoneWidget(from: decoder))
        case "date":
            self = try .date(DateWidget(from: decoder))
        case "close":
            self = try .close(CloseWidget(from: decoder))
        default:
            throw ParsingError.widget(type: type)
        }
    }
}

public extension Widget {
    var id: String {
        return switch self {
        case let .form(widget):
            widget.id
        case let .submit(widget):
            widget.id
        case let .staticWidget(widget):
            widget.id
        case let .input(widget):
            widget.id
        case let .checkbox(widget):
            widget.id
        case let .password(widget):
            widget.id
        case let .select(widget):
            widget.id
        case let .multiselect(widget):
            widget.id
        case let .passcode(widget):
            widget.id
        case let .phone(widget):
            widget.id
        case let .date(widget):
            widget.id
        case let .close(widget):
            widget.id
        }
    }

    var value: Codable? {
        return switch self {
        case .form:
            nil
        case .submit:
            nil
        case .staticWidget:
            nil
        case let .input(widget):
            widget.value
        case let .checkbox(widget):
            widget.value
        case .password:
            nil
        case let .select(widget):
            widget.value
        case let .multiselect(widget):
            widget.value
        case .passcode:
            nil
        case let .phone(widget):
            widget.value
        case let .date(widget):
            widget.value
        case .close:
            nil
        }
    }

    var readonly: Bool {
        return switch self {
        case .form:
            false
        case .submit:
            false
        case .staticWidget:
            false
        case let .input(widget):
            widget.readonly
        case let .checkbox(widget):
            widget.readonly
        case .password:
            false
        case let .select(widget):
            widget.readonly
        case let .multiselect(widget):
            false
        case .passcode:
            false
        case let .phone(widget):
            widget.readonly
        case let .date(widget):
            widget.readonly
        case .close:
            false
        }
    }
}

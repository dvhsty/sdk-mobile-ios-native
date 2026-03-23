@testable import SdkMobileIOSNative
import XCTest

final class ParsingTests: XCTestCase {
    override func setUpWithError() throws {}

    override func tearDownWithError() throws {}

    func testParsing() throws {
        let json = """
        {
          "screen": "identification",
          "branding": {
            "logoUrl": null,
            "copyright": "© 2024 Strivacity, Inc. All rights reserved.",
            "siteTermUrl": "https://www.strivacity.com/terms-of-use/",
            "privacyPolicyUrl": "https://www.strivacity.com/privacy-policy/",
            "styling": {}
          },
          "hostedUrl": "https://tenant.cloud/provider/flow?challenge=676012d80453eec-3f3f-4edb-9df0-e70cdef05272&redirect_uri=ios%3A%2F%2Fnative-flow",
          "forms": [
            {
              "type": "form",
              "id": "identifier",
              "widgets": [
                {
                  "type": "static",
                  "id": "sectionTitle",
                  "value": "Sign in",
                  "render": {
                    "type": "text"
                  }
                },
                {
                  "type": "input",
                  "id": "identifier",
                  "label": "Email address",
                  "value": null,
                  "readonly": false,
                  "autocomplete": "username",
                  "inputmode": "email",
                  "validator": {
                    "minLength": null,
                    "maxLength": null,
                    "regexp": null,
                    "required": true
                  }
                },
                {
                  "id": "submit",
                  "label": "Continue",
                  "render": {
                    "type": "button",
                    "textColor": null,
                    "bgColor": null,
                    "hint": null
                  },
                  "type": "submit"
                }
              ]
            },
            {
              "type": "form",
              "id": "additionalActions/registration",
              "widgets": [
                {
                  "type": "static",
                  "id": "dont-have-an-account",
                  "value": "Don't have an account?",
                  "render": {
                    "type": "text"
                  }
                },
                {
                  "id": "submit",
                  "label": "Sign up",
                  "render": {
                    "type": "link"
                  },
                  "type": "submit"
                }
              ]
            }
          ],
          "layout": {
            "type": "vertical",
            "items": [
              {
                "type": "widget",
                "formId": "identifier",
                "widgetId": "sectionTitle"
              },
              {
                "type": "widget",
                "formId": "identifier",
                "widgetId": "identifier"
              },
              {
                "type": "widget",
                "formId": "identifier",
                "widgetId": "submit"
              },
              {
                "type": "horizontal",
                "items": [
                  {
                    "type": "widget",
                    "formId": "additionalActions/registration",
                    "widgetId": "dont-have-an-account"
                  },
                  {
                    "type": "widget",
                    "formId": "additionalActions/registration",
                    "widgetId": "submit"
                  }
                ]
              }
            ]
          }
        }
        """

        let jsonData = try XCTUnwrap(json.data(using: .utf8))
        let screen = try JSONDecoder().decode(Screen.self, from: jsonData)

        let expected = Screen(
            screen: "identification",
            branding: Branding(
                logoUrl: nil,
                copyright: "© 2024 Strivacity, Inc. All rights reserved.",
                siteTermUrl: "https://www.strivacity.com/terms-of-use/",
                privacyPolicyUrl: "https://www.strivacity.com/privacy-policy/"
            ),
            hostedUrl: "https://tenant.cloud/provider/flow?challenge=676012d80453eec-3f3f-4edb-9df0-e70cdef05272&redirect_uri=ios%3A%2F%2Fnative-flow",
            finalizeUrl: nil,
            forms: [
                FormWidget(
                    id: "identifier",
                    widgets: [
                        .staticWidget(StaticWidget(
                            id: "sectionTitle",
                            value: "Sign in",
                            render: StaticWidget.Render(type: "text")
                        )),
                        .input(InputWidget(
                            id: "identifier",
                            label: "Email address",
                            value: nil,
                            readonly: false,
                            autocomplete: "username",
                            inputmode: "email",
                            validator: InputWidget.Validator(minLength: nil, maxLength: nil, regex: nil, required: true)
                        )),
                        .submit(SubmitWidget(
                            id: "submit",
                            label: "Continue",
                            render: SubmitWidget.Render(
                                type: "button",
                                textColor: nil,
                                bgColor: nil,
                                hint: nil
                            )
                        )),
                    ]
                ),
                FormWidget(
                    id: "additionalActions/registration",
                    widgets: [
                        .staticWidget(StaticWidget(
                            id: "dont-have-an-account",
                            value: "Don't have an account?",
                            render: StaticWidget.Render(type: "text")
                        )),
                        .submit(SubmitWidget(
                            id: "submit",
                            label: "Sign up",
                            render: SubmitWidget.Render(
                                type: "link",
                                textColor: nil,
                                bgColor: nil,
                                hint: nil
                            )
                        )),
                    ]
                ),
            ],
            layout: .vertical(SingleLayout(items: [
                .widget(WidgetLayout(formId: "identifier", widgetId: "sectionTitle")),
                .widget(WidgetLayout(formId: "identifier", widgetId: "identifier")),
                .widget(WidgetLayout(formId: "identifier", widgetId: "submit")),
                .horizontal(SingleLayout(items: [
                    .widget(WidgetLayout(formId: "additionalActions/registration", widgetId: "dont-have-an-account")),
                    .widget(WidgetLayout(formId: "additionalActions/registration", widgetId: "submit")),
                ])),
            ])),
            messages: nil
        )

        XCTAssertEqual(expected, screen)
    }

    func testParseGlobalMessage() throws {
        let json = """
        {
          "hostedUrl": "https://tenant.cloud/provider/flow?challenge=676012d80453eec-3f3f-4edb-9df0-e70cdef05272&redirect_uri=ios%3A%2F%2Fnative-flow",
          "messages": {
            "global": {
              "type": "error",
              "text": "global error"
            }
          }
        }
        """

        let jsonData = try XCTUnwrap(json.data(using: .utf8))
        let screen = try JSONDecoder().decode(Screen.self, from: jsonData)

        let expected = Screen(
            screen: nil,
            branding: nil,
            hostedUrl: "https://tenant.cloud/provider/flow?challenge=676012d80453eec-3f3f-4edb-9df0-e70cdef05272&redirect_uri=ios%3A%2F%2Fnative-flow",
            finalizeUrl: nil,
            forms: nil,
            layout: nil,
            messages: .global(Message(type: "error", text: "global error"))
        )

        XCTAssertEqual(expected, screen)
    }

    func testParseFormMessages() throws {
        let json = """
        {
          "hostedUrl": "https://tenant.cloud/provider/flow?challenge=676012d80453eec-3f3f-4edb-9df0-e70cdef05272&redirect_uri=ios%3A%2F%2Fnative-flow",
          "messages": {
            "identifier": {
              "rememberAccount": {
                "type": "error",
                "text": "field error"
              }
            }
          }
        }
        """

        let jsonData = try XCTUnwrap(json.data(using: .utf8))
        let screen = try JSONDecoder().decode(Screen.self, from: jsonData)

        let expected = Screen(
            screen: nil,
            branding: nil,
            hostedUrl: "https://tenant.cloud/provider/flow?challenge=676012d80453eec-3f3f-4edb-9df0-e70cdef05272&redirect_uri=ios%3A%2F%2Fnative-flow",
            finalizeUrl: nil,
            forms: nil,
            layout: nil,
            messages: .form(["identifier": ["rememberAccount": Message(type: "error", text: "field error")]])
        )

        XCTAssertEqual(expected, screen)
    }

    func testUnkownWidgetType() throws {
        let json = """
        {
          "hostedUrl": "https://tenant.cloud/provider/flow?challenge=676012d80453eec-3f3f-4edb-9df0-e70cdef05272&redirect_uri=ios%3A%2F%2Fnative-flow",
          "forms": [
            {
              "type": "form",
              "id": "identifier",
              "widgets": [
                {
                  "type": "wrongWidget"
                }
              ]
            }
          ]
        }
        """

        let jsonData = try XCTUnwrap(json.data(using: .utf8))

        XCTAssertThrowsError(try JSONDecoder().decode(Screen.self, from: jsonData)) { err in
            XCTAssertEqual(err as! ParsingError, ParsingError.widget(type: "wrongWidget"))
        }
    }

    func testUnkownLayoutType() throws {
        let json = """
        {
          "hostedUrl": "https://tenant.cloud/provider/flow?challenge=676012d80453eec-3f3f-4edb-9df0-e70cdef05272&redirect_uri=ios%3A%2F%2Fnative-flow",
          "layout": {
            "type": "wrongLayout"
          }
        }
        """

        let jsonData = try XCTUnwrap(json.data(using: .utf8))

        XCTAssertThrowsError(try JSONDecoder().decode(Screen.self, from: jsonData)) { err in
            XCTAssertEqual(err as! ParsingError, ParsingError.layout(type: "wrongLayout"))
        }
    }
}

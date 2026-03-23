import Foundation

class LoginHandlerService {
    private let httpService: HttpService
    private let issuer: URL
    private let sessionId: String

    init(httpService: HttpService, issuer: URL, sessionId: String) {
        self.httpService = httpService
        self.issuer = issuer
        self.sessionId = sessionId
    }

    func initCall() async throws -> Screen {
        let initResponse = try await httpService.post(
            url: issuer.appendingPathComponent("/flow/api/v1/init"),
            session: sessionId
        )

        if initResponse.httpResponse.statusCode != 200 && initResponse.httpResponse.statusCode != 400 {
            if initResponse.httpResponse.statusCode == 403 {
                throw NativeSDKError.sessionExpired
            }

            throw NativeSDKError.httpError(statusCode: initResponse.httpResponse.statusCode)
        }

        return try parseScreen(data: initResponse.data)
    }

    func submitForm(formId: String, body: [String: Any]) async throws -> Screen {
        let response = try await httpService.post(
            url: issuer.appendingPathComponent("/flow/api/v1/form/" + formId),
            session: sessionId,
            body: body
        )

        if response.httpResponse.statusCode != 200 && response.httpResponse.statusCode != 400 {
            if response.httpResponse.statusCode == 403 {
                throw NativeSDKError.sessionExpired
            }

            throw NativeSDKError.httpError(statusCode: response.httpResponse.statusCode)
        }

        return try parseScreen(data: response.data)
    }

    private func parseScreen(data: Data) throws -> Screen {
        do {
            return try JSONDecoder().decode(Screen.self, from: data)
        } catch {
            let fallbackScreen = try JSONDecoder().decode(FallbackSceen.self, from: data)
            return Screen(
                screen: nil,
                branding: nil,
                hostedUrl: fallbackScreen.hostedUrl,
                finalizeUrl: nil,
                forms: nil,
                layout: nil,
                messages: nil
            )
        }
    }
}

struct FallbackSceen: Decodable {
    var hostedUrl: String
}

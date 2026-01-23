import Foundation

struct HttpResponse {
    let httpResponse: HTTPURLResponse
    let data: Data
}

class HttpService {
    private enum HttpMethod: String {
        case GET, POST
    }

    private let session: URLSession

    private let logging: Logging

    init(logging: Logging) {
        self.logging = logging
        session = URLSession(
            configuration: .default,
            delegate: HttpSessionDelegate(logging: logging),
            delegateQueue: .main
        )
    }

    func get(url: URL, acceptHeader: String = "application/json") async throws -> HttpResponse {
        let request = createRequest(url: url, method: HttpMethod.GET, acceptHeader: acceptHeader, contentType: nil)
        return try await dataExchange(request: request)
    }

    func post(
        url: URL,
        session: String,
        body: [String: Any]? = nil,
        acceptHeader _: String = "application/json"
    ) async throws -> HttpResponse {
        var jsonData: Data?
        if let body = body {
            jsonData = try JSONSerialization.data(withJSONObject: body, options: [])
        }

        return try await post(url: url, session: session, bodyContent: jsonData, contentType: "application/json")
    }

    func post(
        url: URL,
        session: String? = nil,
        bodyContent: Data? = nil,
        contentType: String = "application/json",
        acceptHeader: String = "application/json"
    ) async throws -> HttpResponse {
        var request = createRequest(
            url: url,
            method: HttpMethod.POST,
            acceptHeader: acceptHeader,
            contentType: contentType
        )

        if let session = session {
            request.setValue("Bearer " + session, forHTTPHeaderField: "Authorization")
        }
        request.httpBody = bodyContent

        return try await dataExchange(request: request)
    }

    private func createRequest(url: URL, method: HttpMethod, acceptHeader: String, contentType: String?) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        if let contentType = contentType {
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }
        request.setValue(acceptHeader, forHTTPHeaderField: "Accept")
        request.setValue(Locale.preferredLanguages[0], forHTTPHeaderField: "Accept-Language")

        return request
    }

    private func dataExchange(request: URLRequest) async throws -> HttpResponse {
        logging
            .debug(
                "REQUEST [\(request.httpMethod ?? "")]: \(request.url?.path ?? "")"
            )
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NativeSDKError.httpError(statusCode: -1)
        }

        if let xEventIdHeader = httpResponse.value(forHTTPHeaderField: "x-event-id"),
           logging.xEventId != xEventIdHeader {
            logging.xEventId = xEventIdHeader
            logging.debug("X-Event-ID updated: \(xEventIdHeader)")
        }
        return HttpResponse(httpResponse: httpResponse, data: data)
    }

    private class HttpSessionDelegate: NSObject, URLSessionDelegate, URLSessionTaskDelegate {
        private let logging: Logging

        init(logging: Logging) {
            self.logging = logging
        }

        func urlSession(
            _: URLSession,
            task _: URLSessionTask,
            willPerformHTTPRedirection _: HTTPURLResponse,
            newRequest request: URLRequest,
            completionHandler: @escaping (URLRequest?) -> Void
        ) {
            if request.url?.scheme == "https" {
                logging.debug("Redirect to \(request.url?.path ?? "")")
                completionHandler(request)
            } else {
                logging
                    .debug(
                        "Redirect to \(request.url?.scheme ?? "")://\(request.url?.host ?? "")/\(request.url?.path ?? "")"
                    )
                completionHandler(nil)
            }
        }
    }
}

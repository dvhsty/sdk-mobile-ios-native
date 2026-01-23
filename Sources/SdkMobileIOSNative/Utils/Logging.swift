import os

public protocol Logging: AnyObject {
    /// Identifier for the login session - can be used to provide additional context for log messages
    ///
    /// Set by NativeSDK when value becomes available and cleared when login attempt finishes or is cancelled
    var xEventId: String? { get set }

    func debug(_ message: String)
    func info(_ message: String)
    func warn(_ message: String)
    func error(_ message: String, error: Error)
}

public class DefaultLogging: Logging {
    private let logger = Logger(
        subsystem: "com.strivacity.sdk",
        category: "NativeSDK"
    )

    public init() {}

    public var xEventId: String?

    private var xEventIdLogPart: String {
        if let xEventId = xEventId {
            return "(\(xEventId)) "
        }
        return ""
    }

    public func debug(_ message: String) {
        let msg = xEventIdLogPart + message
        logger.debug("\(msg)")
    }

    public func info(_ message: String) {
        let msg = xEventIdLogPart + message
        logger.info("\(msg)")
    }

    public func warn(_ message: String) {
        let msg = xEventIdLogPart + message
        logger.info("[W] \(msg)")
    }

    public func error(_ message: String, error: Error) {
        let msg = xEventIdLogPart + message
        logger.debug(
            "\(msg) - Error: \(String(describing: error))"
        )
    }
}

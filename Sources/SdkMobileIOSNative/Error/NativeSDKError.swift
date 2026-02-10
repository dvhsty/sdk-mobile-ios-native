import Foundation

public enum NativeSDKError: Error {
    case oidcError(error: String, errorDescription: String)
    case hostedFlowCanceled
    case invalidCallback(reason: String)
    case sessionExpired

    case httpError(statusCode: Int? = nil)
    case unknownError(source: Error? = nil)
    case workflowError(error: String, errorDescription: String?)
    case genericError(message: String)

    /// Thrown when some technical issue is raised and there is no way for the user to recover from
    ///
    /// - details: optional details about the error (could contain sensitive information, make sure to handle it with
    /// care)
    case technical(message: String, details: [String: String]? = nil)
}

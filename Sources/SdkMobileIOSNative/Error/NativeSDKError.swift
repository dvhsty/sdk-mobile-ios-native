import Foundation

public enum NativeSDKError: Error {
    case oidcError(error: String, errorDescription: String)
    case hostedFlowCanceled
    case invalidCallback(reason: String)
    case sessionExpired

    case httpError(statusCode: Int? = nil)
    case unknownError(source: Error? = nil)
}

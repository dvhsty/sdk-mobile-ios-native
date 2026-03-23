import CommonCrypto
import Foundation

class OIDCParamGenerator {
    static func generateRandomString(byteLengths: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: byteLengths)
        _ = SecRandomCopyBytes(kSecRandomDefault, byteLengths, &bytes)
        return Data(bytes).base64URLEncodedString()
    }

    static func generateCodeVerifier() -> String {
        return OIDCParamGenerator.generateRandomString(byteLengths: 64)
    }

    static func generateCodeChallenge(from verifier: String) -> String {
        let data = verifier.data(using: .ascii)!

        var buffer = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &buffer)
        }

        let hash = Data(buffer)
        return hash.base64URLEncodedString()
    }

    static func generateState() -> String {
        return OIDCParamGenerator.generateRandomString(byteLengths: 16)
    }

    static func generateNonce() -> String {
        return OIDCParamGenerator.generateRandomString(byteLengths: 16)
    }
}

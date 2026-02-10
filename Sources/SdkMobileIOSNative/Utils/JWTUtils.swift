import Foundation

class JWTUtils {
    static func parseJWT(_ jwt: String) throws -> [String: Any] {
        let sections = jwt.components(separatedBy: ".")

        let header = try parseBase64Section(section: sections[0])
        return try parseBase64Section(section: sections[1])
    }

    private static func parseBase64Section(section: String) throws -> [String: Any] {
        var base64 = section
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        if base64.count % 4 != 0 {
            base64.append(String(repeating: "=", count: 4 - base64.count % 4))
        }

        guard
            let encodedData = base64.data(using: .utf8),
            let data = Data(base64Encoded: encodedData),
            let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            throw NativeSDKError.technical(message: "Unable to parse JWT contents")
        }

        return json
    }
}

import Foundation

class JWTUtils {
    static func parseJWT(_ jwt: String) -> [String: Any] {
        let sections = jwt.components(separatedBy: ".")

        assert(sections.count == 3, "Invalid JWT returned")

        let header = parseBase64Section(section: sections[0])
        return parseBase64Section(section: sections[1])
    }

    private static func parseBase64Section(section: String) -> [String: Any] {
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
            assert(false, "Unable to parse the JWT content")
        }

        return json
    }
}

import SwiftUI

struct HtmlTextView: View {
    @State var attributedString: AttributedString?
    @State var processingError: Bool = false

    @Binding var htmlContent: String

    var body: some View {
        ZStack {
            if let attributedString = attributedString {
                Text(attributedString)
            } else if processingError {
                FallbackTriggerView()
            }
        }
        .onAppear {
            updateHtmlContent()
        }
        .onChange(of: htmlContent) { _ in
            updateHtmlContent()
        }
    }

    private func updateHtmlContent() {
        DispatchQueue.main.async { [self] in
            let font = UIFont.preferredFont(forTextStyle: .body)
            let html = """
            <style>
            * {
                font-family: '-apple-system', '\(font.familyName)';
                font-size: \(font.pointSize);
            }
            a {
                color: \(hexStringFromColor(color: .link));
            }
            </style>
            \(htmlContent)
            """
            do {
                let nsattr = try NSAttributedString(
                    data: Data(html.utf8),
                    options: [
                        .documentType: NSAttributedString.DocumentType.html,
                        .characterEncoding: String.Encoding.utf8.rawValue,
                    ],
                    documentAttributes: nil
                )
                attributedString = AttributedString(nsattr)
            } catch {
                processingError = true
            }
        }
    }

    func hexStringFromColor(color: UIColor) -> String {
        let components = color.cgColor.components
        let red: CGFloat = components?[0] ?? 0.0
        let green: CGFloat = components?[1] ?? 0.0
        let blue: CGFloat = components?[2] ?? 0.0

        return String(
            format: "#%02lX%02lX%02lX",
            lroundf(Float(red * 255)),
            lroundf(Float(green * 255)),
            lroundf(Float(blue * 255))
        )
    }
}

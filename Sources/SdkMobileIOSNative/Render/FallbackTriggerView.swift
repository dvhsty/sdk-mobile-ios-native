import SwiftUI

public struct FallbackTriggerView: View {
    @EnvironmentObject var loginController: LoginController

    public init() {}

    public var body: some View {
        VStack {}
            .task {
                do {
                    try await loginController.triggerFallback()
                } catch {
                    print("Could not trigger fallback: \(error)")
                }
            }
    }
}

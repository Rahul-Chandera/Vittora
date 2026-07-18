import Foundation
import Observation
import VittoraCore

@Observable
@MainActor
final class SubscriptionAuditViewModel {
    var report: SubscriptionAuditReport?
    var isLoading = false
    var error: String?

    private let useCase: SubscriptionAuditUseCase

    init(useCase: SubscriptionAuditUseCase) {
        self.useCase = useCase
    }

    var isEmpty: Bool {
        report?.rows.isEmpty ?? true
    }

    func load() async {
        isLoading = true
        error = nil
        do {
            report = try await useCase.execute()
        } catch {
            self.error = error.userFacingMessage(
                fallback: String(localized: "We couldn't load the subscription audit right now.")
            )
        }
        isLoading = false
    }
}

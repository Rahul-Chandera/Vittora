import Foundation
import Observation
import VittoraCore

@Observable
@MainActor
final class DebtAnalyticsViewModel {
    var analytics: DebtAnalytics?
    var isLoading = false
    var error: String?

    private let useCase: CalculateDebtAnalyticsUseCase

    init(useCase: CalculateDebtAnalyticsUseCase) {
        self.useCase = useCase
    }

    var hasData: Bool {
        analytics?.hasData ?? false
    }

    func load() async {
        isLoading = true
        error = nil
        do {
            analytics = try await useCase.execute()
        } catch {
            self.error = error.userFacingMessage(
                fallback: String(localized: "We couldn't load debt analytics right now.")
            )
        }
        isLoading = false
    }
}

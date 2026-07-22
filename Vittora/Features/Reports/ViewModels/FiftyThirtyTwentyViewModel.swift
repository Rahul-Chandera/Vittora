import Foundation
import Observation
import VittoraCore

@Observable
@MainActor
final class FiftyThirtyTwentyViewModel {
    var selectedMonth: Date
    var snapshot: FiftyThirtyTwentyReportSnapshot?
    var isLoading = false
    var error: String?

    private let useCase: FiftyThirtyTwentyReportUseCase

    init(
        useCase: FiftyThirtyTwentyReportUseCase,
        selectedMonth: Date = .now
    ) {
        self.useCase = useCase
        self.selectedMonth = selectedMonth
    }

    func load() async {
        isLoading = true
        error = nil
        do {
            snapshot = try await useCase.execute(month: selectedMonth)
        } catch {
            self.error = error.userFacingMessage(
                fallback: String(localized: "We couldn't load this comparison right now.")
            )
        }
        isLoading = false
    }
}

import Foundation

@Observable
@MainActor
final class TaxEstimateViewModel {
    private let estimateUseCase: EstimateTaxUseCase
    private let saveUseCase: SaveTaxProfileUseCase

    var profile: TaxProfile = TaxProfile()
    var estimate: TaxEstimate?
    var isLoading = false
    var error: String?

    init(estimateUseCase: EstimateTaxUseCase, saveUseCase: SaveTaxProfileUseCase) {
        self.estimateUseCase = estimateUseCase
        self.saveUseCase = saveUseCase
    }

    func load() async {
        isLoading = true
        error = nil
        do {
            profile = try await saveUseCase.fetchOrDefault()
            if profile.annualIncome > 0 {
                estimate = estimateUseCase.execute(profile: profile)
            }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func recalculate() {
        guard profile.annualIncome > 0 else { estimate = nil; return }
        estimate = estimateUseCase.execute(profile: profile)
    }
}

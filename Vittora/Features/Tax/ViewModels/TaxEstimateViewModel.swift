import Foundation

@Observable
@MainActor
final class TaxEstimateViewModel {
    private let estimateUseCase: EstimateTaxUseCase
    private let compareUseCase: CompareTaxRegimesUseCase
    private let saveUseCase: SaveTaxProfileUseCase
    private let summaryUseCase: GenerateTaxSummaryUseCase?

    var profile: TaxProfile = TaxProfile()
    var estimate: TaxEstimate?
    var comparison: TaxComparison?
    var summary: TaxSummary?
    var isLoading = false
    var error: String?

    init(
        estimateUseCase: EstimateTaxUseCase,
        compareUseCase: CompareTaxRegimesUseCase,
        saveUseCase: SaveTaxProfileUseCase,
        summaryUseCase: GenerateTaxSummaryUseCase? = nil
    ) {
        self.estimateUseCase = estimateUseCase
        self.compareUseCase = compareUseCase
        self.saveUseCase = saveUseCase
        self.summaryUseCase = summaryUseCase
    }

    func load() async {
        isLoading = true
        error = nil
        do {
            profile = try await saveUseCase.fetchOrDefault()
            if profile.annualIncome > 0 {
                estimate = estimateUseCase.execute(profile: profile)
                comparison = compareUseCase.execute(profile: profile)
                if let summaryUseCase {
                    summary = try await summaryUseCase.execute(profile: profile)
                } else {
                    summary = nil
                }
            } else {
                estimate = nil
                comparison = nil
                summary = nil
            }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func recalculate() {
        guard profile.annualIncome > 0 else {
            estimate = nil
            comparison = nil
            summary = nil
            return
        }
        estimate = estimateUseCase.execute(profile: profile)
        comparison = compareUseCase.execute(profile: profile)
    }
}

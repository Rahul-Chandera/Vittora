import Foundation

@Observable
@MainActor
final class TaxProfileFormViewModel {
    private let saveUseCase: SaveTaxProfileUseCase
    private let estimateUseCase: EstimateTaxUseCase
    private let compareUseCase: CompareTaxRegimesUseCase

    // Form fields
    var country: TaxCountry = .india
    var incomeString = ""
    var indiaRegime: IndiaRegime = .newRegime
    var filingStatus: USFilingStatus = .single
    var financialYear = "2024-25"
    var customDeductions: [TaxDeduction] = []

    // Live preview
    var liveEstimate: TaxEstimate?
    var liveComparison: TaxComparison?

    var isSaving = false
    var error: String?

    var income: Decimal { Decimal(string: incomeString.replacingOccurrences(of: ",", with: "")) ?? 0 }
    var canSave: Bool { income > 0 }

    init(
        saveUseCase: SaveTaxProfileUseCase,
        estimateUseCase: EstimateTaxUseCase,
        compareUseCase: CompareTaxRegimesUseCase
    ) {
        self.saveUseCase = saveUseCase
        self.estimateUseCase = estimateUseCase
        self.compareUseCase = compareUseCase
    }

    func populate(from profile: TaxProfile) {
        country = profile.country
        incomeString = profile.annualIncome == 0 ? "" : "\(profile.annualIncome)"
        indiaRegime = profile.indiaRegime
        filingStatus = profile.filingStatus
        financialYear = profile.financialYear
        customDeductions = profile.customDeductions
        recalculateLive()
    }

    func recalculateLive() {
        guard income > 0 else {
            liveEstimate = nil
            liveComparison = nil
            return
        }

        let profile = currentProfile()
        liveEstimate = estimateUseCase.execute(profile: profile)
        liveComparison = compareUseCase.execute(profile: profile)
    }

    func addDeduction(name: String, amount: Decimal, section: String?) {
        let deduction = TaxDeduction(name: name, amount: amount, section: section)
        customDeductions.append(deduction)
        recalculateLive()
    }

    func removeDeduction(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) {
            customDeductions.remove(at: index)
        }
        recalculateLive()
    }

    func save() async throws {
        isSaving = true
        error = nil
        do {
            try await saveUseCase.execute(currentProfile())
        } catch {
            self.error = error.localizedDescription
            isSaving = false
            throw error
        }
        isSaving = false
    }

    private func currentProfile() -> TaxProfile {
        TaxProfile(
            country: country,
            annualIncome: income,
            indiaRegime: indiaRegime,
            filingStatus: filingStatus,
            customDeductions: customDeductions,
            financialYear: financialYear
        )
    }
}

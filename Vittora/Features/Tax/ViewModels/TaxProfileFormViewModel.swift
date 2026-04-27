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
    var financialYear = TaxCountry.india.defaultFinancialYear
    var incomeSourceType: IncomeSourceType = .salaried
    var dateOfBirth: Date? = nil
    var customDeductions: [TaxDeduction] = []

    // Live preview
    var liveEstimate: TaxEstimate?
    var liveComparison: TaxComparison?

    var isSaving = false
    var error: String?
    private var loadedProfile: TaxProfile?

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
        loadedProfile = profile
        country = profile.country
        incomeString = profile.annualIncome == 0 ? "" : "\(profile.annualIncome)"
        indiaRegime = profile.indiaRegime
        filingStatus = profile.filingStatus
        financialYear = profile.financialYear
        incomeSourceType = profile.incomeSourceType
        dateOfBirth = profile.dateOfBirth
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
            let profileToSave = currentProfile()
            try await saveUseCase.execute(profileToSave)
            loadedProfile = profileToSave
        } catch {
            self.error = error.localizedDescription
            isSaving = false
            throw error
        }
        isSaving = false
    }

    private func currentProfile() -> TaxProfile {
        var profile = loadedProfile ?? TaxProfile()
        profile.country = country
        profile.annualIncome = income
        profile.indiaRegime = indiaRegime
        profile.filingStatus = filingStatus
        profile.customDeductions = customDeductions
        profile.financialYear = financialYear
        profile.incomeSourceType = incomeSourceType
        profile.dateOfBirth = dateOfBirth
        profile.updatedAt = .now
        return profile
    }
}

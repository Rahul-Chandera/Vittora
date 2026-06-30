import Foundation
import VittoraCore

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
    var advancedInputs = TaxAdvancedInputs()

    var indiaBasicSalaryString = ""
    var indiaHRAPaidString = ""
    var indiaRentPaidString = ""

    // Live preview
    var liveEstimate: TaxEstimate?
    var liveComparison: TaxComparison?
    var indiaDeductionUtilization: [IndiaSectionDeductionEngine.Utilization] = []

    var isSaving = false
    var error: String?
    private var loadedProfile: TaxProfile?

    private var parsedIncome: Decimal? {
        Decimal(localizedAmount: incomeString)
    }

    var income: Decimal { parsedIncome ?? 0 }
    var canSave: Bool { (parsedIncome ?? 0) > 0 }

    var section80CUtilization: IndiaSectionDeductionEngine.Utilization? {
        indiaDeductionUtilization.first { $0.sectionKey == "80C" }
    }

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
        advancedInputs = profile.advancedInputs
        syncIndiaInputStringsFromAdvancedInputs()
        recalculateLive()
    }

    func recalculateLive() {
        syncAdvancedInputsFromStrings()
        guard income > 0 else {
            liveEstimate = nil
            liveComparison = nil
            indiaDeductionUtilization = []
            return
        }

        let profile = currentProfile()
        liveEstimate = estimateUseCase.execute(profile: profile)
        liveComparison = compareUseCase.execute(profile: profile)

        if country == .india, indiaRegime == .oldRegime {
            let resolution = IndiaSectionDeductionEngine.resolve(
                deductions: customDeductions,
                advancedInputs: advancedInputs,
                dateOfBirth: dateOfBirth,
                financialYearLabel: financialYear
            )
            indiaDeductionUtilization = resolution.utilizations
        } else {
            indiaDeductionUtilization = []
        }
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
        guard let parsedIncome = parsedIncome, parsedIncome > 0 else {
            throw VittoraError.validationFailed(String(localized: "Please enter a valid annual income."))
        }
        syncAdvancedInputsFromStrings()
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
        profile.advancedInputs = advancedInputs
        profile.updatedAt = .now
        return profile
    }

    private func syncAdvancedInputsFromStrings() {
        if let basic = Decimal(localizedAmount: indiaBasicSalaryString) {
            advancedInputs.indiaBasicSalary = basic
        } else if indiaBasicSalaryString.isEmpty {
            advancedInputs.indiaBasicSalary = 0
        }
        if let hra = Decimal(localizedAmount: indiaHRAPaidString) {
            advancedInputs.indiaHRAPaid = hra
        } else if indiaHRAPaidString.isEmpty {
            advancedInputs.indiaHRAPaid = 0
        }
        if let rent = Decimal(localizedAmount: indiaRentPaidString) {
            advancedInputs.indiaRentPaid = rent
        } else if indiaRentPaidString.isEmpty {
            advancedInputs.indiaRentPaid = 0
        }
    }

    private func syncIndiaInputStringsFromAdvancedInputs() {
        indiaBasicSalaryString = advancedInputs.indiaBasicSalary > 0
            ? "\(advancedInputs.indiaBasicSalary)"
            : ""
        indiaHRAPaidString = advancedInputs.indiaHRAPaid > 0
            ? "\(advancedInputs.indiaHRAPaid)"
            : ""
        indiaRentPaidString = advancedInputs.indiaRentPaid > 0
            ? "\(advancedInputs.indiaRentPaid)"
            : ""
    }
}

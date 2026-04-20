import Foundation
import Testing
@testable import Vittora

@Suite("TaxProfileFormViewModel Tests")
@MainActor
struct TaxProfileFormViewModelTests {

    private func makeViewModel(taxRepo: MockTaxProfileRepository) -> TaxProfileFormViewModel {
        TaxProfileFormViewModel(
            saveUseCase: SaveTaxProfileUseCase(taxProfileRepository: taxRepo),
            estimateUseCase: EstimateTaxUseCase(),
            compareUseCase: CompareTaxRegimesUseCase()
        )
    }

    // MARK: - canSave

    @Test("canSave is false when incomeString is empty")
    func canSaveFalseWhenEmpty() {
        let vm = makeViewModel(taxRepo: MockTaxProfileRepository())
        vm.incomeString = ""
        #expect(vm.canSave == false)
    }

    @Test("canSave is false when income is zero")
    func canSaveFalseWhenZero() {
        let vm = makeViewModel(taxRepo: MockTaxProfileRepository())
        vm.incomeString = "0"
        #expect(vm.canSave == false)
    }

    @Test("canSave is true when income is positive")
    func canSaveTrueWhenPositive() {
        let vm = makeViewModel(taxRepo: MockTaxProfileRepository())
        vm.incomeString = "500000"
        #expect(vm.canSave == true)
    }

    // MARK: - income computed property

    @Test("income parses plain integer string")
    func incomeParsesInteger() {
        let vm = makeViewModel(taxRepo: MockTaxProfileRepository())
        vm.incomeString = "75000"
        #expect(vm.income == 75000)
    }

    @Test("income strips commas before parsing")
    func incomeStripsCommas() {
        let vm = makeViewModel(taxRepo: MockTaxProfileRepository())
        vm.incomeString = "1,200,000"
        #expect(vm.income == Decimal(string: "1200000")!)
    }

    @Test("income returns zero for non-numeric string")
    func incomeZeroForInvalidString() {
        let vm = makeViewModel(taxRepo: MockTaxProfileRepository())
        vm.incomeString = "abc"
        #expect(vm.income == 0)
    }

    // MARK: - populate(from:)

    @Test("populate fills all fields from profile")
    func populateFillsFields() {
        let vm = makeViewModel(taxRepo: MockTaxProfileRepository())
        let dob = Date(timeIntervalSince1970: 631_152_000)
        let deduction = TaxDeduction(name: "80C", amount: 150_000, section: "80C")
        let profile = TaxProfile(
            country: .india,
            annualIncome: 1_000_000,
            indiaRegime: .oldRegime,
            filingStatus: .single,
            customDeductions: [deduction],
            financialYear: "2024-25",
            incomeSourceType: .salaried,
            dateOfBirth: dob
        )

        vm.populate(from: profile)

        #expect(vm.country == .india)
        #expect(vm.incomeString == "1000000")
        #expect(vm.indiaRegime == .oldRegime)
        #expect(vm.financialYear == "2024-25")
        #expect(vm.incomeSourceType == .salaried)
        #expect(vm.dateOfBirth == dob)
        #expect(vm.customDeductions.count == 1)
    }

    @Test("populate with zero income sets empty incomeString")
    func populateZeroIncomeEmptyString() {
        let vm = makeViewModel(taxRepo: MockTaxProfileRepository())
        let profile = TaxProfile(country: .india, annualIncome: 0)
        vm.populate(from: profile)
        #expect(vm.incomeString == "")
    }

    // MARK: - recalculateLive

    @Test("recalculateLive clears estimate when income is zero")
    func recalculateLiveClearsForZeroIncome() {
        let vm = makeViewModel(taxRepo: MockTaxProfileRepository())
        vm.incomeString = ""
        vm.recalculateLive()
        #expect(vm.liveEstimate == nil)
        #expect(vm.liveComparison == nil)
    }

    @Test("recalculateLive sets estimate when income is positive")
    func recalculateLiveSetsEstimate() {
        let vm = makeViewModel(taxRepo: MockTaxProfileRepository())
        vm.incomeString = "500000"
        vm.recalculateLive()
        #expect(vm.liveEstimate != nil)
    }

    // MARK: - addDeduction / removeDeduction

    @Test("addDeduction appends to customDeductions")
    func addDeductionAppends() {
        let vm = makeViewModel(taxRepo: MockTaxProfileRepository())
        vm.incomeString = "800000"
        vm.addDeduction(name: "80C", amount: 150_000, section: "80C")
        #expect(vm.customDeductions.count == 1)
        #expect(vm.customDeductions.first?.name == "80C")
    }

    @Test("removeDeduction removes at correct index")
    func removeDeductionRemovesAtIndex() {
        let vm = makeViewModel(taxRepo: MockTaxProfileRepository())
        vm.incomeString = "800000"
        vm.addDeduction(name: "80C", amount: 150_000, section: "80C")
        vm.addDeduction(name: "80D", amount: 25_000, section: "80D")
        vm.removeDeduction(at: IndexSet([0]))
        #expect(vm.customDeductions.count == 1)
        #expect(vm.customDeductions.first?.name == "80D")
    }

    // MARK: - save()

    @Test("save() persists profile to repository")
    func savePersistsProfile() async throws {
        let taxRepo = MockTaxProfileRepository()
        let vm = makeViewModel(taxRepo: taxRepo)
        vm.incomeString = "700000"

        try await vm.save()

        #expect(taxRepo.profile?.annualIncome == 700_000)
        #expect(vm.isSaving == false)
        #expect(vm.error == nil)
    }

    @Test("save() sets error and rethrows on repository failure")
    func saveRethrowsOnError() async {
        let taxRepo = MockTaxProfileRepository()
        taxRepo.shouldThrowError = true
        let vm = makeViewModel(taxRepo: taxRepo)
        vm.incomeString = "500000"

        await #expect(throws: (any Error).self) {
            try await vm.save()
        }
        #expect(vm.error != nil)
        #expect(vm.isSaving == false)
    }
}

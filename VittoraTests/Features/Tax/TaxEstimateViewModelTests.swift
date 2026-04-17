import Foundation
import Testing

@testable import Vittora

@Suite("Tax Estimate ViewModel Tests")
@MainActor
struct TaxEstimateViewModelTests {

    @Test("load populates estimate comparison and summary from a saved profile")
    func loadPopulatesDerivedTaxData() async throws {
        let profile = TaxProfile(
            country: .india,
            annualIncome: 900_000,
            indiaRegime: .newRegime,
            financialYear: "2024-25"
        )
        let categoryRepository = MockCategoryRepository()
        let transactionRepository = MockTransactionRepository()
        let healthCategory = CategoryEntity(name: "Health", icon: "heart.fill", type: .expense)
        await categoryRepository.seed(healthCategory)
        try await transactionRepository.create(TransactionEntity(
            amount: 12_000,
            date: makeTaxDate(year: 2024, month: 6, day: 1),
            type: .expense,
            categoryID: healthCategory.id
        ))

        let viewModel = TaxEstimateViewModel(
            estimateUseCase: EstimateTaxUseCase(),
            compareUseCase: CompareTaxRegimesUseCase(),
            saveUseCase: SaveTaxProfileUseCase(
                taxProfileRepository: StubTaxProfileRepository(profile: profile)
            ),
            summaryUseCase: GenerateTaxSummaryUseCase(
                transactionRepository: transactionRepository,
                fetchTaxCategoriesUseCase: FetchTaxCategoriesUseCase(repository: categoryRepository)
            )
        )

        await viewModel.load()

        #expect(viewModel.profile == profile)
        #expect(viewModel.estimate?.grossIncome == 900_000)
        #expect(viewModel.comparison != nil)
        #expect(viewModel.summary?.totalRelevantAmount == 12_000)
        #expect(viewModel.summary?.transactionCount == 1)
        #expect(viewModel.error == nil)
    }

    @Test("load clears derived tax data when no saved income is available")
    func loadClearsDerivedStateForDefaultProfile() async {
        let viewModel = TaxEstimateViewModel(
            estimateUseCase: EstimateTaxUseCase(),
            compareUseCase: CompareTaxRegimesUseCase(),
            saveUseCase: SaveTaxProfileUseCase(
                taxProfileRepository: StubTaxProfileRepository(profile: nil)
            )
        )

        await viewModel.load()

        #expect(viewModel.profile.annualIncome == 0)
        #expect(viewModel.estimate == nil)
        #expect(viewModel.comparison == nil)
        #expect(viewModel.summary == nil)
        #expect(viewModel.error == nil)
    }

    @Test("load surfaces repository failures")
    func loadSurfacesRepositoryFailures() async {
        let viewModel = TaxEstimateViewModel(
            estimateUseCase: EstimateTaxUseCase(),
            compareUseCase: CompareTaxRegimesUseCase(),
            saveUseCase: SaveTaxProfileUseCase(
                taxProfileRepository: FailingTaxProfileRepository()
            )
        )

        await viewModel.load()

        #expect(viewModel.estimate == nil)
        #expect(viewModel.comparison == nil)
        #expect(viewModel.summary == nil)
        #expect(viewModel.error?.contains("Mock error") == true)
    }
}

private actor StubTaxProfileRepository: TaxProfileRepository {
    let profile: TaxProfile?

    init(profile: TaxProfile?) {
        self.profile = profile
    }

    func fetch() async throws -> TaxProfile? {
        profile
    }

    func save(_ profile: TaxProfile) async throws {}
    func delete() async throws {}
}

private actor FailingTaxProfileRepository: TaxProfileRepository {
    func fetch() async throws -> TaxProfile? {
        throw VittoraError.unknown(String(localized: "Mock error"))
    }

    func save(_ profile: TaxProfile) async throws {}
    func delete() async throws {}
}

private func makeTaxDate(year: Int, month: Int, day: Int) -> Date {
    let calendar = Calendar(identifier: .gregorian)
    return calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .now
}

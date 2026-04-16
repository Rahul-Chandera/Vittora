import Foundation
import Testing

@testable import Vittora

@Suite("Tax Export ViewModel Tests")
@MainActor
struct TaxExportViewModelTests {

    @Test("export report stores shared file URL on success")
    func exportReportStoresURL() async {
        let exportURL = URL(fileURLWithPath: "/tmp/vittora_tax_report.csv")
        let exportService = MockDataExportService(resultURL: exportURL)
        let viewModel = makeViewModel(exportService: exportService)

        viewModel.profile = sampleTaxProfile()
        viewModel.estimate = sampleTaxEstimate()
        viewModel.comparison = sampleTaxComparison()
        viewModel.summary = sampleTaxSummary()

        await viewModel.exportReport()

        #expect(viewModel.exportURL == exportURL)
        #expect(viewModel.error == nil)
        #expect(viewModel.isExporting == false)
    }

    @Test("export report surfaces service failures")
    func exportReportStoresErrorOnFailure() async {
        let exportService = MockDataExportService(
            resultURL: URL(fileURLWithPath: "/tmp/unused.csv"),
            shouldFailTaxExport: true
        )
        let viewModel = makeViewModel(exportService: exportService)
        viewModel.profile = sampleTaxProfile()
        viewModel.estimate = sampleTaxEstimate()

        await viewModel.exportReport()

        #expect(viewModel.exportURL == nil)
        #expect(viewModel.error?.contains("Export error") == true)
    }

    @Test("export report requires an estimate")
    func exportReportRequiresEstimate() async {
        let exportService = MockDataExportService(resultURL: URL(fileURLWithPath: "/tmp/unused.csv"))
        let viewModel = makeViewModel(exportService: exportService)
        viewModel.profile = sampleTaxProfile()

        await viewModel.exportReport()

        #expect(viewModel.exportURL == nil)
        #expect(viewModel.error == "Generate a tax estimate before exporting a report.")
    }
}

@MainActor
private func makeViewModel(
    exportService: any DataExportServiceProtocol
) -> TaxEstimateViewModel {
    TaxEstimateViewModel(
        estimateUseCase: EstimateTaxUseCase(),
        compareUseCase: CompareTaxRegimesUseCase(),
        saveUseCase: SaveTaxProfileUseCase(taxProfileRepository: MockTaxProfileRepository()),
        exportService: exportService
    )
}

private actor MockTaxProfileRepository: TaxProfileRepository {
    func fetch() async throws -> TaxProfile? { nil }
    func save(_ profile: TaxProfile) async throws {}
    func delete() async throws {}
}

private actor MockDataExportService: DataExportServiceProtocol {
    let resultURL: URL
    let shouldFailTaxExport: Bool

    init(resultURL: URL, shouldFailTaxExport: Bool = false) {
        self.resultURL = resultURL
        self.shouldFailTaxExport = shouldFailTaxExport
    }

    func exportTransactionsCSV(filter: TransactionFilter?) async throws -> URL {
        resultURL
    }

    func exportTransactions(
        startDate: Date?,
        endDate: Date?,
        format: ExportFormat
    ) async throws -> URL {
        resultURL
    }

    func exportTaxReportCSV(
        profile: TaxProfile,
        estimate: TaxEstimate,
        comparison: TaxComparison?,
        summary: TaxSummary?
    ) async throws -> URL {
        if shouldFailTaxExport {
            throw VittoraError.exportFailed(String(localized: "Tax export failed"))
        }
        return resultURL
    }
}

private func sampleTaxProfile() -> TaxProfile {
    TaxProfile(
        country: .india,
        annualIncome: 1_500_000,
        indiaRegime: .newRegime,
        financialYear: "2024-25"
    )
}

private func sampleTaxEstimate() -> TaxEstimate {
    TaxEstimate(
        grossIncome: 1_500_000,
        standardDeduction: 75_000,
        customDeductionsTotal: 0,
        taxableIncome: 1_425_000,
        bracketResults: [
            TaxBracketResult(label: "0 - 1,425,000", ratePercent: 18, taxableAmount: 1_425_000, taxAmount: 275_000),
        ],
        basicTax: 275_000,
        rebate: 0,
        surcharge: 0,
        cess: 11_000,
        finalTax: 286_000,
        effectiveRate: 0.1907,
        marginalRate: 20,
        country: .india,
        regimeLabel: "New Regime"
    )
}

private func sampleTaxComparison() -> TaxComparison {
    let firstEstimate = sampleTaxEstimate()
    let secondEstimate = TaxEstimate(
        grossIncome: 1_500_000,
        standardDeduction: 50_000,
        customDeductionsTotal: 0,
        taxableIncome: 1_450_000,
        bracketResults: [
            TaxBracketResult(label: "0 - 1,450,000", ratePercent: 20, taxableAmount: 1_450_000, taxAmount: 290_000),
        ],
        basicTax: 290_000,
        rebate: 0,
        surcharge: 0,
        cess: 11_600,
        finalTax: 301_600,
        effectiveRate: 0.2011,
        marginalRate: 20,
        country: .india,
        regimeLabel: "Old Regime"
    )

    return TaxComparison(
        kind: .indiaRegimes,
        firstEstimate: firstEstimate,
        secondEstimate: secondEstimate,
        winner: .first,
        savingsAmount: 15_600
    )
}

private func sampleTaxSummary() -> TaxSummary {
    let category = CategoryEntity(name: "Health", icon: "heart.fill", type: .expense)
    return TaxSummary(
        financialYear: "2024-25",
        dateRange: sampleDate(year: 2024, month: 4, day: 1)...sampleDate(year: 2025, month: 3, day: 31),
        totalRelevantAmount: 24_000,
        transactionCount: 2,
        taxRelevantCategories: [category],
        categoryBreakdown: [
            TaxSummaryCategory(category: category, totalAmount: 24_000, transactionCount: 2),
        ]
    )
}

private func sampleDate(year: Int, month: Int, day: Int) -> Date {
    let calendar = Calendar(identifier: .gregorian)
    return calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .now
}

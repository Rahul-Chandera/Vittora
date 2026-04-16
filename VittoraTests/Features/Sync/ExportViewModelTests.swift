import Foundation
import Testing

@testable import Vittora

@Suite("Export ViewModel Tests")
@MainActor
struct ExportViewModelTests {

    @Test("export stores shared file URL on success")
    func exportStoresURLOnSuccess() async {
        let url = URL(fileURLWithPath: "/tmp/vittora_export.csv")
        let exportService = MockExportService(resultURL: url)
        let viewModel = ExportViewModel(exportService: exportService)

        await viewModel.export()

        #expect(viewModel.exportURL == url)
        #expect(viewModel.error == nil)
        #expect(viewModel.isExporting == false)
        #expect(viewModel.progressPhase == nil)
    }

    @Test("export uses the custom date range when enabled")
    func exportUsesCustomDateRange() async {
        let url = URL(fileURLWithPath: "/tmp/vittora_export.csv")
        let exportService = MockExportService(resultURL: url)
        let viewModel = ExportViewModel(exportService: exportService)
        let startDate = Calendar.current.date(byAdding: .day, value: -14, to: .now) ?? .now
        let endDate = Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now

        viewModel.useCustomDateRange = true
        viewModel.startDate = startDate
        viewModel.endDate = endDate

        await viewModel.export()

        let request = await exportService.lastRequest
        #expect(request?.startDate == startDate)
        #expect(request?.endDate == endDate)
        #expect(request?.format == .csv)
    }

    @Test("export surfaces failures and clears progress state")
    func exportStoresErrorOnFailure() async {
        let exportService = MockExportService(
            resultURL: URL(fileURLWithPath: "/tmp/vittora_export.csv"),
            shouldFail: true
        )
        let viewModel = ExportViewModel(exportService: exportService)

        await viewModel.export()

        #expect(viewModel.exportURL == nil)
        #expect(viewModel.error?.contains("Export error") == true)
        #expect(viewModel.isExporting == false)
        #expect(viewModel.progressPhase == nil)
    }
}

private actor MockExportService: DataExportServiceProtocol {
    struct Request: Sendable, Equatable {
        let startDate: Date?
        let endDate: Date?
        let format: ExportFormat
    }

    let resultURL: URL
    let shouldFail: Bool
    private(set) var lastRequest: Request?

    init(resultURL: URL, shouldFail: Bool = false) {
        self.resultURL = resultURL
        self.shouldFail = shouldFail
    }

    func exportTransactionsCSV(filter: TransactionFilter?) async throws -> URL {
        resultURL
    }

    func exportTransactions(
        startDate: Date?,
        endDate: Date?,
        format: ExportFormat
    ) async throws -> URL {
        lastRequest = Request(startDate: startDate, endDate: endDate, format: format)
        if shouldFail {
            throw VittoraError.exportFailed(String(localized: "Transaction export failed"))
        }
        return resultURL
    }

    func exportTaxReportCSV(
        profile: TaxProfile,
        estimate: TaxEstimate,
        comparison: TaxComparison?,
        summary: TaxSummary?
    ) async throws -> URL {
        resultURL
    }
}

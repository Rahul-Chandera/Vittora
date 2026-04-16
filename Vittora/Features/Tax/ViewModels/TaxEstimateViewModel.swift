import Foundation

@Observable
@MainActor
final class TaxEstimateViewModel {
    private let estimateUseCase: EstimateTaxUseCase
    private let compareUseCase: CompareTaxRegimesUseCase
    private let saveUseCase: SaveTaxProfileUseCase
    private let summaryUseCase: GenerateTaxSummaryUseCase?
    private let exportService: (any DataExportServiceProtocol)?

    var profile: TaxProfile = TaxProfile()
    var estimate: TaxEstimate?
    var comparison: TaxComparison?
    var summary: TaxSummary?
    var isLoading = false
    var isExporting = false
    var exportURL: URL?
    var error: String?

    init(
        estimateUseCase: EstimateTaxUseCase,
        compareUseCase: CompareTaxRegimesUseCase,
        saveUseCase: SaveTaxProfileUseCase,
        summaryUseCase: GenerateTaxSummaryUseCase? = nil,
        exportService: (any DataExportServiceProtocol)? = nil
    ) {
        self.estimateUseCase = estimateUseCase
        self.compareUseCase = compareUseCase
        self.saveUseCase = saveUseCase
        self.summaryUseCase = summaryUseCase
        self.exportService = exportService
    }

    func load() async {
        isLoading = true
        error = nil
        exportURL = nil
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

    func exportReport() async {
        guard let exportService else {
            error = String(localized: "Tax export is not available right now.")
            return
        }
        guard let estimate else {
            error = String(localized: "Generate a tax estimate before exporting a report.")
            return
        }

        isExporting = true
        error = nil
        exportURL = nil
        defer { isExporting = false }

        do {
            exportURL = try await exportService.exportTaxReportCSV(
                profile: profile,
                estimate: estimate,
                comparison: comparison,
                summary: summary
            )
        } catch {
            self.error = error.localizedDescription
        }
    }

    func clearExportURL() {
        exportURL = nil
    }
}

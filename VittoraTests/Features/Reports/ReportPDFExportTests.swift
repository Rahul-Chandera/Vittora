import Testing
import SwiftUI
@testable import Vittora

@Suite("Report PDF Export Tests")
@MainActor
struct ReportPDFExportTests {

    @Test("12-month monthly report produces multi-page PDF with magic bytes")
    func monthlyExportProducesMultiPagePDF() throws {
        let data = Self.seededTwelveMonths()
        let totals = Self.totals(for: data)

        let pages = MonthlyReportPDFDocument.pages(
            reportTitle: "Monthly Overview",
            period: "Last 12 months",
            monthlyData: data,
            currencyCode: "USD",
            totalIncome: totals.income,
            totalExpense: totals.expense,
            netSavings: totals.net
        )

        #expect(pages.count >= 2)

        let url = try ReportPDFRenderer.export(pages: pages, fileName: "test-monthly-12")
        let bytes = try Data(contentsOf: url)
        #expect(!bytes.isEmpty)
        #expect(bytes.starts(with: Data("%PDF".utf8)))
        #expect(ReportPDFRenderer.pageCount(at: url) >= 2)

        // Always leave a copy for PR verification (temp dir is sandbox-writable).
        let sampleURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("R1-sample-monthly-overview.pdf")
        if FileManager.default.fileExists(atPath: sampleURL.path) {
            try FileManager.default.removeItem(at: sampleURL)
        }
        try FileManager.default.copyItem(at: url, to: sampleURL)
    }

    @Test("Annual summary export produces multi-page PDF with magic bytes")
    func annualExportProducesMultiPagePDF() throws {
        let data = Self.seededTwelveMonths()
        let totals = Self.totals(for: data)

        let pages = MonthlyReportPDFDocument.pages(
            reportTitle: "Annual Summary",
            period: "Year 2026",
            monthlyData: data,
            currencyCode: "USD",
            totalIncome: totals.income,
            totalExpense: totals.expense,
            netSavings: totals.net
        )

        let url = try ReportPDFRenderer.export(pages: pages, fileName: "test-annual-12")
        let bytes = try Data(contentsOf: url)
        #expect(bytes.starts(with: Data("%PDF".utf8)))
        #expect(ReportPDFRenderer.pageCount(at: url) >= 2)
    }

    @Test("Custom report export produces non-empty PDF")
    func customExportProducesPDF() throws {
        let result = CustomReportResult(
            dateRange: nil,
            grouping: .category,
            transactionType: .expense,
            rows: [
                CustomReportRow(label: "Food", amount: 120, count: 4, percentage: 60),
                CustomReportRow(label: "Transport", amount: 80, count: 2, percentage: 40),
            ],
            total: 200
        )

        let url = try ReportPDFExporter.export(
            CustomReportExportDocument(result: result, currencyCode: "USD"),
            fileName: "test-custom"
        )
        let bytes = try Data(contentsOf: url)
        #expect(!bytes.isEmpty)
        #expect(bytes.starts(with: Data("%PDF".utf8)))
    }

    private static func seededTwelveMonths() -> [MonthlyData] {
        let calendar = Calendar(identifier: .gregorian)
        var data: [MonthlyData] = []
        for month in 1...12 {
            let date = calendar.date(from: DateComponents(year: 2026, month: month, day: 1)) ?? .now
            data.append(
                MonthlyData(
                    month: date,
                    income: Decimal(4_000 + month * 100),
                    expense: Decimal(2_500 + month * 80)
                )
            )
        }
        return data
    }

    private static func totals(for data: [MonthlyData]) -> (income: Decimal, expense: Decimal, net: Decimal) {
        let income = data.reduce(Decimal(0)) { $0 + $1.income }
        let expense = data.reduce(Decimal(0)) { $0 + $1.expense }
        return (income, expense, income - expense)
    }
}

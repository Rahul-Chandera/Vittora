import Testing
import SwiftUI
@testable import Vittora

@Suite("Report PDF Export Tests")
@MainActor
struct ReportPDFExportTests {

    @Test("Monthly report export produces non-empty PDF")
    func monthlyExportProducesPDF() throws {
        let sampleMonth = Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 1)) ?? .now
        let data = [
            MonthlyData(month: sampleMonth, income: 5_000, expense: 3_200),
            MonthlyData(
                month: Calendar.current.date(byAdding: .month, value: -1, to: sampleMonth) ?? sampleMonth,
                income: 4_800,
                expense: 2_900
            ),
        ]

        let document = MonthlyReportExportDocument(
            reportTitle: "Monthly Overview",
            subtitle: "Last 12 months",
            monthlyData: data,
            currencyCode: "USD",
            totalIncome: 9_800,
            totalExpense: 6_100,
            netSavings: 3_700
        )

        let url = try ReportPDFExporter.export(document, fileName: "test-monthly")
        let bytes = try Data(contentsOf: url)
        #expect(!bytes.isEmpty)
        #expect(bytes.starts(with: Data("%PDF".utf8)))
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
}

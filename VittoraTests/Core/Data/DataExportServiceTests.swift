import Testing
import Foundation
@testable import Vittora

@Suite("DataExportService Tests")
@MainActor
struct DataExportServiceTests {

    private func makeService(transactions: [TransactionEntity] = []) -> (DataExportService, MockTransactionRepository) {
        let repo = MockTransactionRepository()
        Task { for tx in transactions { try await repo.create(tx) } }
        let service = DataExportService(transactionRepository: repo)
        return (service, repo)
    }

    @Test("exports empty CSV with header only")
    func emptyExportHasHeader() async throws {
        let (service, _) = makeService()
        let url = try await service.exportTransactionsCSV(filter: nil)
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("Date,Amount,Type,Category,Account,Payee,Payment Method,Notes,Tags"))
    }

    @Test("exported CSV has UTF-8 BOM")
    func exportHasUTF8BOM() async throws {
        let (service, _) = makeService()
        let url = try await service.exportTransactionsCSV(filter: nil)
        let data = try Data(contentsOf: url)
        // UTF-8 BOM is EF BB BF
        #expect(data.prefix(3) == Data([0xEF, 0xBB, 0xBF]))
    }

    @Test("exports one row per transaction")
    func exportRowCount() async throws {
        let repo = MockTransactionRepository()
        for i in 0..<3 {
            let tx = TransactionEntity(
                amount: Decimal(i + 1) * 10,
                note: "TX \(i)",
                type: .expense,
                paymentMethod: .cash
            )
            try await repo.create(tx)
        }
        let service = DataExportService(transactionRepository: repo)
        let url = try await service.exportTransactionsCSV(filter: nil)
        let content = try String(contentsOf: url, encoding: .utf8)
        let lines = content.components(separatedBy: "\n").filter { !$0.isEmpty }
        // 1 header + 3 data rows
        #expect(lines.count == 4)
    }

    @Test("transaction amount appears in CSV")
    func exportAmountPresent() async throws {
        let repo = MockTransactionRepository()
        let tx = TransactionEntity(
            amount: 42.50,
            note: "Coffee",
            type: .expense,
            paymentMethod: .cash
        )
        try await repo.create(tx)
        let service = DataExportService(transactionRepository: repo)
        let url = try await service.exportTransactionsCSV(filter: nil)
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("42.5"))
    }

    @Test("transaction note appears correctly in CSV")
    func exportNotePresent() async throws {
        let repo = MockTransactionRepository()
        let tx = TransactionEntity(
            amount: 10,
            note: "Lunch at office",
            type: .expense,
            paymentMethod: .cash
        )
        try await repo.create(tx)
        let service = DataExportService(transactionRepository: repo)
        let url = try await service.exportTransactionsCSV(filter: nil)
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("Lunch at office"))
    }

    @Test("double-quotes in notes are escaped per RFC 4180")
    func exportDoubleQuoteEscaping() async throws {
        let repo = MockTransactionRepository()
        let tx = TransactionEntity(
            amount: 5,
            note: "He said \"hello\"",
            type: .expense,
            paymentMethod: .cash
        )
        try await repo.create(tx)
        let service = DataExportService(transactionRepository: repo)
        let url = try await service.exportTransactionsCSV(filter: nil)
        let content = try String(contentsOf: url, encoding: .utf8)
        // RFC 4180: " is doubled to ""
        #expect(content.contains("He said \"\"hello\"\""))
    }

    @Test("export with date range filter returns only matching transactions")
    func exportWithDateFilter() async throws {
        let repo = MockTransactionRepository()
        let calendar = Calendar.current
        let now = Date.now
        let pastDate = calendar.date(byAdding: .day, value: -10, to: now)!
        let futureDate = calendar.date(byAdding: .day, value: 10, to: now)!

        let old = TransactionEntity(amount: 1, date: pastDate, type: .expense, paymentMethod: .cash)
        let recent = TransactionEntity(amount: 2, date: now, type: .expense, paymentMethod: .cash)
        let future = TransactionEntity(amount: 3, date: futureDate, type: .expense, paymentMethod: .cash)

        try await repo.create(old)
        try await repo.create(recent)
        try await repo.create(future)

        let service = DataExportService(transactionRepository: repo)
        let filterStart = calendar.date(byAdding: .day, value: -5, to: now)!
        let filterEnd   = calendar.date(byAdding: .day, value:  5, to: now)!
        let filter = TransactionFilter(dateRange: filterStart...filterEnd)
        let url = try await service.exportTransactionsCSV(filter: filter)
        let content = try String(contentsOf: url, encoding: .utf8)
        let lines = content.components(separatedBy: "\n").filter { !$0.isEmpty }
        // Should only have header + 1 row (the "recent" transaction)
        #expect(lines.count == 2)
    }

    @Test("exportTransactions with no date range exports all")
    func exportTransactionsNoFilter() async throws {
        let repo = MockTransactionRepository()
        for i in 0..<5 {
            let tx = TransactionEntity(amount: Decimal(i), type: .income, paymentMethod: .bankTransfer)
            try await repo.create(tx)
        }
        let service = DataExportService(transactionRepository: repo)
        let url = try await service.exportTransactions(startDate: nil, endDate: nil, format: .csv)
        let content = try String(contentsOf: url, encoding: .utf8)
        let lines = content.components(separatedBy: "\n").filter { !$0.isEmpty }
        #expect(lines.count == 6) // header + 5
    }

    @Test("exported file has .csv extension")
    func exportedFileExtension() async throws {
        let (service, _) = makeService()
        let url = try await service.exportTransactionsCSV(filter: nil)
        #expect(url.pathExtension == "csv")
    }

    @Test("exported filename contains date prefix")
    func exportedFilenameContainsDate() async throws {
        let (service, _) = makeService()
        let url = try await service.exportTransactionsCSV(filter: nil)
        #expect(url.lastPathComponent.hasPrefix("vittora_"))
    }

    @Test("tax export includes the required disclaimer")
    func taxExportIncludesDisclaimer() async throws {
        let (service, _) = makeService()
        let url = try await service.exportTaxReportCSV(
            profile: sampleTaxProfile(),
            estimate: sampleTaxEstimate(),
            comparison: nil,
            summary: nil
        )

        let content = try String(contentsOf: url, encoding: .utf8)

        #expect(content.contains(TaxDisclaimer.text))
        #expect(content.contains("Total Tax Payable"))
    }

    @Test("tax export includes summary and comparison sections")
    func taxExportIncludesSummaryAndComparison() async throws {
        let (service, _) = makeService()
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
        let comparison = TaxComparison(
            kind: .indiaRegimes,
            firstEstimate: firstEstimate,
            secondEstimate: secondEstimate,
            winner: .first,
            savingsAmount: 26_000
        )

        let url = try await service.exportTaxReportCSV(
            profile: sampleTaxProfile(),
            estimate: firstEstimate,
            comparison: comparison,
            summary: sampleTaxSummary()
        )

        let content = try String(contentsOf: url, encoding: .utf8)

        #expect(content.contains("India Regime Comparison"))
        #expect(content.contains("Health"))
        #expect(content.contains("Potentially Relevant Amount"))
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

private func sampleTaxSummary() -> TaxSummary {
    let category = CategoryEntity(name: "Health", icon: "heart.fill", type: .expense)
    return TaxSummary(
        financialYear: "2024-25",
        dateRange: makeDate(year: 2024, month: 4, day: 1)...makeDate(year: 2025, month: 3, day: 31),
        totalRelevantAmount: 24_000,
        transactionCount: 2,
        taxRelevantCategories: [category],
        categoryBreakdown: [
            TaxSummaryCategory(category: category, totalAmount: 24_000, transactionCount: 2),
        ]
    )
}

private func makeDate(year: Int, month: Int, day: Int) -> Date {
    let calendar = Calendar(identifier: .gregorian)
    return calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .now
}

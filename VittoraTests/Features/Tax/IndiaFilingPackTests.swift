import Foundation
import Testing
import VittoraCore
@testable import Vittora

/// The filing pack goes to a CA, so the financial-year boundary, which spending lands
/// under which section, and what is left out are what these pin.
@MainActor
@Suite("India Filing Pack Tests")
struct IndiaFilingPackTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Kolkata") ?? .current
        return calendar
    }
    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)) ?? .now
    }

    private let salary = CategoryEntity(name: "Salary", icon: "briefcase", type: .income)
    private let interest = CategoryEntity(name: "Interest", icon: "percent", type: .income)
    private let insurance = CategoryEntity(name: "Health Insurance", icon: "cross")
    private let rentCategory = CategoryEntity(name: "Rent", icon: "house")
    private let gifts = CategoryEntity(name: "Gifts", icon: "gift")
    private let lic = PayeeEntity(name: "LIC")

    private func expense(_ amount: Decimal, on day: Date, category: CategoryEntity? = nil,
                         payee: PayeeEntity? = nil, note: String? = nil, currency: String = "INR") -> TransactionEntity {
        TransactionEntity(amount: amount, date: day, note: note, type: .expense, currencyCode: currency,
                          categoryID: category?.id, payeeID: payee?.id)
    }

    private func build(_ transactions: [TransactionEntity], profile: TaxProfile = TaxProfile(financialYear: "2026-27")) throws -> IndiaFilingPack {
        try #require(IndiaFilingPackBuilder.build(
            financialYear: "2026-27",
            transactions: transactions,
            categories: [salary, interest, insurance, rentCategory, gifts],
            payees: [lic],
            profile: profile,
            comparison: nil,
            calendar: calendar
        ))
    }

    @Test("FY 2026-27 runs from 1 April 2026 to the end of 31 March 2027")
    func financialYearBoundary() throws {
        let period = try #require(IndiaFilingPackBuilder.period(forFinancialYear: "2026-27", calendar: calendar))
        #expect(period.contains(date(2026, 4, 1)))
        #expect(period.contains(date(2027, 3, 31)))
        #expect(!period.contains(date(2026, 3, 31)))
        #expect(!period.contains(date(2027, 4, 1)))
    }

    @Test("Income is grouped by category, largest first, within the year only")
    func incomeByCategory() throws {
        let pack = try build([
            TransactionEntity(amount: 150_000, date: date(2026, 5, 1), type: .income, currencyCode: "INR", categoryID: salary.id),
            TransactionEntity(amount: 150_000, date: date(2026, 6, 1), type: .income, currencyCode: "INR", categoryID: salary.id),
            TransactionEntity(amount: 4_200, date: date(2026, 9, 30), type: .income, currencyCode: "INR", categoryID: interest.id),
            TransactionEntity(amount: 150_000, date: date(2026, 3, 1), type: .income, currencyCode: "INR", categoryID: salary.id), // FY 2025-26
        ])
        #expect(pack.incomeByCategory.map(\.name) == ["Salary", "Interest"])
        #expect(pack.incomeByCategory.first?.amount == 300_000)
        #expect(pack.totalIncome == 304_200)
    }

    @Test("Spending lands under the right section: NPS is not 80C, 'Parent' is not rent")
    func sectionsMatch() throws {
        let pack = try build([
            expense(25_000, on: date(2026, 7, 1), payee: lic),                                // 80C
            expense(50_000, on: date(2026, 8, 1), note: "NPS contribution"),                 // 80CCD(1B)
            expense(18_000, on: date(2026, 8, 5), category: insurance),                      // 80D
            expense(30_000, on: date(2026, 9, 1), category: rentCategory),                   // rent
            expense(2_000, on: date(2026, 9, 2), category: gifts, note: "Gift for parent"),   // nothing
            expense(5_000, on: date(2026, 10, 2), note: "Donation to Akshaya Patra"),        // 80G
        ])
        let sections = Dictionary(uniqueKeysWithValues: pack.evidence.map { ($0.section, $0.total) })
        #expect(sections[.section80C] == 25_000)
        #expect(sections[.section80CCD1B] == 50_000)
        #expect(sections[.section80D] == 18_000)
        #expect(sections[.rent] == 30_000)
        #expect(sections[.section80G] == 5_000)
        #expect(sections.count == 5)
        #expect(pack.evidence.first { $0.section == .section80C }?.rows.first?.description == "LIC")
    }

    @Test("Other currencies are counted out, and the count is kept")
    func otherCurrencies() throws {
        let pack = try build([
            expense(1_000, on: date(2026, 7, 1), category: rentCategory),
            expense(800, on: date(2026, 7, 2), category: rentCategory, currency: "USD"),
        ])
        #expect(pack.evidence.first?.total == 1_000)
        #expect(pack.excludedOtherCurrencyCount == 1)
    }

    @Test("Declared deductions come from the tax profile")
    func declaredDeductions() throws {
        let profile = TaxProfile(
            customDeductions: [TaxDeduction(name: "PPF", amount: 150_000, section: "80C"), TaxDeduction(name: "Empty", amount: 0)],
            financialYear: "2026-27"
        )
        let pack = try build([], profile: profile)
        #expect(pack.declaredDeductions.map(\.name) == ["80C · PPF"])
        #expect(pack.evidence.isEmpty)
    }

    @Test("The PDF has a summary page plus a page per section of evidence")
    func pdfPages() throws {
        let pack = try build([
            expense(25_000, on: date(2026, 7, 1), payee: lic),
            expense(30_000, on: date(2026, 9, 1), category: rentCategory),
        ])
        let url = try IndiaFilingPackPDF.export(pack)
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(ReportPDFRenderer.pageCount(at: url) == 3)
    }
}

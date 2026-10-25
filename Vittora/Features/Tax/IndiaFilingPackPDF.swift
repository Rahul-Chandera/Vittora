import SwiftUI
import VittoraCore

/// The filing pack as an A4 PDF for a CA: a summary page, then the transactions behind
/// each deduction, a page at a time.
@MainActor
enum IndiaFilingPackPDF {
    static let rowsPerPage = 30

    static func export(_ pack: IndiaFilingPack, currencyCode: String = "INR") throws -> URL {
        var pages: [AnyView] = [AnyView(SummaryPage(pack: pack, currencyCode: currencyCode))]
        for evidence in pack.evidence {
            let chunks = stride(from: 0, to: evidence.rows.count, by: rowsPerPage).map {
                Array(evidence.rows[$0..<min($0 + rowsPerPage, evidence.rows.count)])
            }
            for (index, chunk) in chunks.enumerated() {
                pages.append(AnyView(EvidencePage(
                    pack: pack, evidence: evidence, rows: chunk,
                    continued: index > 0, currencyCode: currencyCode
                )))
            }
        }
        return try ReportPDFRenderer.export(pages: pages, fileName: "vittora-india-filing-pack-\(pack.financialYear)")
    }

    // MARK: - Pages

    private struct SummaryPage: View {
        let pack: IndiaFilingPack
        let currencyCode: String

        var body: some View {
            VStack(alignment: .leading, spacing: 18) {
                Header(pack: pack)

                block(String(localized: "Income recorded")) {
                    if pack.incomeByCategory.isEmpty {
                        Text(String(localized: "No income recorded in this financial year."))
                    } else {
                        ForEach(pack.incomeByCategory) { line in row(line.name, line.amount) }
                        row(String(localized: "Total"), pack.totalIncome, bold: true)
                    }
                }

                if let comparison = pack.regimeComparison {
                    block(String(localized: "Regime comparison (estimate)")) {
                        row(comparison.firstEstimate.regimeLabel, comparison.firstEstimate.finalTax)
                        row(comparison.secondEstimate.regimeLabel, comparison.secondEstimate.finalTax)
                    }
                }

                block(String(localized: "Deductions declared in Vittora")) {
                    if pack.declaredDeductions.isEmpty {
                        Text(String(localized: "None declared in the tax profile."))
                    } else {
                        ForEach(pack.declaredDeductions) { line in row(line.name, line.amount) }
                    }
                }

                block(String(localized: "Spending that may support a deduction")) {
                    if pack.evidence.isEmpty {
                        Text(String(localized: "No matching spending found. Matching looks for words such as PPF, LIC, health insurance, NPS, donation and rent in categories, payees and notes."))
                    } else {
                        ForEach(pack.evidence) { item in
                            row("\(item.section.title) · \(item.rows.count)", item.total)
                        }
                    }
                }

                Spacer(minLength: 0)
                Footer(pack: pack)
            }
            .padding(36)
            .font(.system(size: 11))
            .foregroundStyle(Color.black)
        }

        private func block<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.system(size: 13, weight: .semibold))
                content()
            }
        }

        private func row(_ label: String, _ amount: Decimal, bold: Bool = false) -> some View {
            HStack {
                Text(label)
                Spacer()
                Text(CurrencyFormatter.format(amount, currencyCode: currencyCode)).monospacedDigit()
            }
            .fontWeight(bold ? .semibold : .regular)
        }
    }

    private struct EvidencePage: View {
        let pack: IndiaFilingPack
        let evidence: IndiaFilingPack.Evidence
        let rows: [IndiaFilingPack.EvidenceRow]
        let continued: Bool
        let currencyCode: String

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                Header(pack: pack)
                Text(continued ? String(localized: "\(evidence.section.title) (continued)") : evidence.section.title)
                    .font(.system(size: 13, weight: .semibold))
                ForEach(rows) { row in
                    HStack(alignment: .firstTextBaseline) {
                        Text(row.date.formatted(date: .numeric, time: .omitted))
                            .frame(width: 80, alignment: .leading)
                        Text(row.description)
                            .lineLimit(1)
                        Spacer()
                        Text(CurrencyFormatter.format(row.amount, currencyCode: currencyCode)).monospacedDigit()
                    }
                }
                if !continued {
                    HStack {
                        Text(String(localized: "Total")).fontWeight(.semibold)
                        Spacer()
                        Text(CurrencyFormatter.format(evidence.total, currencyCode: currencyCode))
                            .fontWeight(.semibold).monospacedDigit()
                    }
                }
                Spacer(minLength: 0)
                Footer(pack: pack)
            }
            .padding(36)
            .font(.system(size: 10))
            .foregroundStyle(Color.black)
        }
    }

    private struct Header: View {
        let pack: IndiaFilingPack
        var body: some View {
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "India filing pack · FY \(pack.financialYear)"))
                    .font(.system(size: 18, weight: .bold))
                Text(String(localized: "From the records in Vittora, \(pack.period.lowerBound.formatted(date: .long, time: .omitted)) to \(pack.period.upperBound.formatted(date: .long, time: .omitted))"))
                    .font(.system(size: 10))
                    .foregroundStyle(Color.gray)
            }
        }
    }

    private struct Footer: View {
        let pack: IndiaFilingPack
        var body: some View {
            VStack(alignment: .leading, spacing: 3) {
                if pack.excludedOtherCurrencyCount > 0 {
                    Text(String(localized: "\(pack.excludedOtherCurrencyCount) transactions in other currencies are not included."))
                }
                Text(String(localized: "An educational summary of your own records to discuss with your CA. It is not tax advice and not a return. Section labels are those of the Income-tax Act, 1961; from tax year 2026-27 the Income-tax Act, 2025 renumbered sections."))
            }
            .font(.system(size: 8))
            .foregroundStyle(Color.gray)
        }
    }
}

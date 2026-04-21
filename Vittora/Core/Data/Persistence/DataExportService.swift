import Foundation
import os.signpost
import OSLog
import Security

enum ExportFormat: String, CaseIterable, Sendable {
    case csv = "CSV"

    var fileExtension: String { rawValue.lowercased() }
    var mimeType: String {
        switch self {
        case .csv: return "text/csv"
        }
    }
}

protocol DataExportServiceProtocol: Sendable {
    func exportTransactionsCSV(filter: TransactionFilter?) async throws -> URL
    func exportTransactions(
        startDate: Date?,
        endDate: Date?,
        format: ExportFormat
    ) async throws -> URL
    func cleanupTemporaryExport(at url: URL) async
    func exportTaxReportCSV(
        profile: TaxProfile,
        estimate: TaxEstimate,
        comparison: TaxComparison?,
        summary: TaxSummary?
    ) async throws -> URL
}

@MainActor
final class DataExportService: DataExportServiceProtocol, Sendable {
    private static let logger = Logger(subsystem: "com.vittora.app", category: "export")
    private let transactionRepository: any TransactionRepository
    private let accountRepository: (any AccountRepository)?
    private let categoryRepository: (any CategoryRepository)?
    private let payeeRepository: (any PayeeRepository)?
    private let auditLogger: (any SecurityAuditLogging)?

    init(
        transactionRepository: any TransactionRepository,
        accountRepository: (any AccountRepository)? = nil,
        categoryRepository: (any CategoryRepository)? = nil,
        payeeRepository: (any PayeeRepository)? = nil,
        auditLogger: (any SecurityAuditLogging)? = nil
    ) {
        self.transactionRepository = transactionRepository
        self.accountRepository = accountRepository
        self.categoryRepository = categoryRepository
        self.payeeRepository = payeeRepository
        self.auditLogger = auditLogger
    }

    // MARK: - Legacy compatibility

    func exportTransactionsCSV(filter: TransactionFilter?) async throws -> URL {
        let signpostID = PerformanceLogger.Export.beginCSV()
        defer { PerformanceLogger.Export.endCSV(id: signpostID) }
        let transactions = try await transactionRepository.fetchAll(filter: filter)
        let csv = try await buildCSV(for: transactions)
        return try writeToTemp(content: csv, suffix: "transactions")
    }

    // MARK: - Full export with date range

    func exportTransactions(
        startDate: Date?,
        endDate: Date?,
        format: ExportFormat
    ) async throws -> URL {
        let dateRange: ClosedRange<Date>? = {
            guard let start = startDate, let end = endDate else { return nil }
            return start <= end ? start...end : end...start
        }()
        let filter = TransactionFilter(dateRange: dateRange)
        let transactions = try await transactionRepository.fetchAll(filter: filter)

        switch format {
        case .csv:
            let csv = try await buildCSV(for: transactions)
            return try writeToTemp(content: csv, suffix: "transactions")
        }
    }

    func exportTaxReportCSV(
        profile: TaxProfile,
        estimate: TaxEstimate,
        comparison: TaxComparison?,
        summary: TaxSummary?
    ) async throws -> URL {
        let csv = buildTaxReportCSV(
            profile: profile,
            estimate: estimate,
            comparison: comparison,
            summary: summary
        )
        return try writeToTemp(content: csv, suffix: "tax_report")
    }

    func cleanupTemporaryExport(at url: URL) async {
        do {
            try securelyDeleteFile(at: url)
        } catch {
            Self.logger.error(
                "Failed to securely delete temporary export at \(url.path, privacy: .private): \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    // MARK: - CSV builder

    private func buildCSV(for transactions: [TransactionEntity]) async throws -> String {
        // Build lookup maps for human-readable names
        var accountMap: [UUID: String] = [:]
        var categoryMap: [UUID: String] = [:]
        var payeeMap: [UUID: String] = [:]

        if let accountRepo = accountRepository {
            let accounts = try await accountRepo.fetchAll()
            accountMap = Dictionary(uniqueKeysWithValues: accounts.map { ($0.id, $0.name) })
        }
        if let catRepo = categoryRepository {
            let categories = try await catRepo.fetchAll()
            categoryMap = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.name) })
        }
        if let payeeRepo = payeeRepository {
            let payees = try await payeeRepo.fetchAll()
            payeeMap = Dictionary(uniqueKeysWithValues: payees.map { ($0.id, $0.name) })
        }

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate]

        // UTF-8 BOM for Excel compatibility
        var csv = "\u{FEFF}"
        csv += "Date,Amount,Type,Category,Account,Payee,Payment Method,Notes,Tags\n"

        for tx in transactions {
            let date = dateFormatter.string(from: tx.date)
            let amount = "\(tx.amount)"
            let type = tx.type.rawValue.capitalized
            let category = tx.categoryID.flatMap { categoryMap[$0] } ?? ""
            let account  = tx.accountID.flatMap  { accountMap[$0]  } ?? ""
            let payee    = tx.payeeID.flatMap     { payeeMap[$0]    } ?? ""
            let method   = tx.paymentMethod.rawValue
            let note     = tx.note ?? ""
            let tags     = tx.tags.joined(separator: ";")

            appendCSVRow(
                [date, amount, type, category, account, payee, method, note, tags],
                to: &csv
            )
        }

        return csv
    }

    private func buildTaxReportCSV(
        profile: TaxProfile,
        estimate: TaxEstimate,
        comparison: TaxComparison?,
        summary: TaxSummary?
    ) -> String {
        var csv = "\u{FEFF}"
        csv += "Section,Field,Value,Notes\n"

        appendCSVRow(["Tax Report", "Disclaimer", TaxDisclaimer.text, ""], to: &csv)
        appendCSVRow(["Profile", "Country", profile.country.displayName, ""], to: &csv)
        appendCSVRow(["Profile", "Financial Year", profile.financialYear, ""], to: &csv)
        appendCSVRow(
            ["Profile", "Annual Income", profile.annualIncome.formatted(.currency(code: estimate.country.currencyCode)), ""],
            to: &csv
        )
        appendCSVRow(["Estimate", "Regime", estimate.regimeLabel, ""], to: &csv)
        appendCSVRow(
            ["Estimate", "Taxable Income", estimate.taxableIncome.formatted(.currency(code: estimate.country.currencyCode)), ""],
            to: &csv
        )
        appendCSVRow(
            ["Estimate", "Total Tax Payable", estimate.finalTax.formatted(.currency(code: estimate.country.currencyCode)), ""],
            to: &csv
        )
        appendCSVRow(
            ["Estimate", "Effective Rate", percentageString(estimate.effectiveRate * 100), ""],
            to: &csv
        )
        appendCSVRow(
            ["Estimate", "Marginal Rate", percentageString(estimate.marginalRate), ""],
            to: &csv
        )

        for bracket in estimate.bracketResults {
            appendCSVRow(
                [
                    "Bracket",
                    bracket.label,
                    bracket.taxAmount.formatted(.currency(code: estimate.country.currencyCode)),
                    "\(percentageString(bracket.ratePercent)) on \(bracket.taxableAmount.formatted(.currency(code: estimate.country.currencyCode)))",
                ],
                to: &csv
            )
        }

        if let comparison {
            appendCSVRow(
                ["Comparison", "Type", comparisonKindLabel(comparison.kind), ""],
                to: &csv
            )
            appendCSVRow(
                ["Comparison", comparison.firstEstimate.regimeLabel, comparison.firstEstimate.finalTax.formatted(.currency(code: estimate.country.currencyCode)), ""],
                to: &csv
            )
            appendCSVRow(
                ["Comparison", comparison.secondEstimate.regimeLabel, comparison.secondEstimate.finalTax.formatted(.currency(code: estimate.country.currencyCode)), ""],
                to: &csv
            )
            appendCSVRow(
                ["Comparison", "Recommended", comparison.recommendedEstimate?.regimeLabel ?? String(localized: "Tie"), ""],
                to: &csv
            )
            appendCSVRow(
                ["Comparison", "Potential Savings", comparison.savingsAmount.formatted(.currency(code: estimate.country.currencyCode)), ""],
                to: &csv
            )
        }

        if let summary {
            appendCSVRow(["Tax Summary", "Financial Year", summary.financialYear, formattedDateRange(summary.dateRange)], to: &csv)
            appendCSVRow(
                ["Tax Summary", "Potentially Relevant Amount", summary.totalRelevantAmount.formatted(.currency(code: estimate.country.currencyCode)), ""],
                to: &csv
            )
            appendCSVRow(
                ["Tax Summary", "Transaction Count", summary.transactionCount.formatted(), ""],
                to: &csv
            )
            appendCSVRow(
                ["Tax Summary", "Matched Categories", summary.matchedCategoryCount.formatted(), ""],
                to: &csv
            )

            for item in summary.categoryBreakdown {
                appendCSVRow(
                    [
                        "Tax Category",
                        item.category.name,
                        item.totalAmount.formatted(.currency(code: estimate.country.currencyCode)),
                        String(localized: "\(item.transactionCount.formatted()) transaction(s)"),
                    ],
                    to: &csv
                )
            }
        }

        return csv
    }

    private func appendCSVRow(_ values: [String], to csv: inout String) {
        csv += values
            .map { "\"\($0.csvEscaped)\"" }
            .joined(separator: ",")
        csv += "\n"
    }

    private func percentageString(_ value: Decimal) -> String {
        value.formatted(.number.precision(.fractionLength(1))) + "%"
    }

    private func comparisonKindLabel(_ kind: TaxComparisonKind) -> String {
        switch kind {
        case .indiaRegimes:
            String(localized: "India Regime Comparison")
        case .usDeductionModes:
            String(localized: "US Deduction Comparison")
        }
    }

    private func formattedDateRange(_ range: ClosedRange<Date>) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.string(from: range.lowerBound) + " - " + formatter.string(from: range.upperBound)
    }

    // MARK: - File writer

    private func writeToTemp(content: String, suffix: String) throws -> URL {
        let dateStr = ISO8601DateFormatter().string(from: .now)
            .prefix(10) // YYYY-MM-DD
        let fileName = "vittora_\(suffix)_\(dateStr).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        guard let data = content.data(using: .utf8) else {
            throw VittoraError.exportFailed(String(localized: "Failed to encode CSV as UTF-8"))
        }

        do {
            #if os(iOS)
            try data.write(to: url, options: [.atomic, .completeFileProtection])
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.complete],
                ofItemAtPath: url.path
            )
            #else
            try data.write(to: url, options: [.atomic])
            #endif
            if let auditLogger {
                let name = url.lastPathComponent
                Task { await auditLogger.record(SecurityAuditEvent(kind: .exportCreated, detail: name)) }
            }
            return url
        } catch {
            throw VittoraError.exportFailed(
                String(localized: "Failed to write CSV: \(error.localizedDescription)")
            )
        }
    }

    private func securelyDeleteFile(at url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = (attributes[.size] as? NSNumber)?.intValue ?? 0

        if fileSize > 0 {
            let handle = try FileHandle(forWritingTo: url)
            defer {
                do {
                    try handle.close()
                } catch {
                    Self.logger.error(
                        "Failed to close temporary export file handle for \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)"
                    )
                }
            }

            try handle.seek(toOffset: 0)

            var remainingBytes = fileSize
            while remainingBytes > 0 {
                let chunkSize = min(remainingBytes, 64 * 1024)
                try handle.write(contentsOf: randomData(count: chunkSize))
                remainingBytes -= chunkSize
            }

            try handle.synchronize()
        }

        try FileManager.default.removeItem(at: url)
    }

    private func randomData(count: Int) throws -> Data {
        guard count > 0 else { return Data() }

        var data = Data(count: count)
        let status = data.withUnsafeMutableBytes { buffer in
            guard let baseAddress = buffer.baseAddress else {
                return errSecParam
            }
            return SecRandomCopyBytes(kSecRandomDefault, count, baseAddress)
        }

        guard status == errSecSuccess else {
            throw VittoraError.exportFailed(
                String(localized: "Failed to generate secure random bytes for export cleanup.")
            )
        }

        return data
    }
}

// MARK: - String CSV helper

private extension String {
    /// Escape double quotes and neutralize spreadsheet formula injection.
    var csvEscaped: String {
        let formulaPrefixes = ["=", "+", "-", "@", "\t", "\r", "\n"]
        let sanitized = formulaPrefixes.contains(where: hasPrefix) ? "'" + self : self
        return sanitized.replacingOccurrences(of: "\"", with: "\"\"")
    }
}

import Foundation

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
}

@MainActor
final class DataExportService: DataExportServiceProtocol, Sendable {
    private let transactionRepository: any TransactionRepository
    private let accountRepository: (any AccountRepository)?
    private let categoryRepository: (any CategoryRepository)?
    private let payeeRepository: (any PayeeRepository)?

    init(
        transactionRepository: any TransactionRepository,
        accountRepository: (any AccountRepository)? = nil,
        categoryRepository: (any CategoryRepository)? = nil,
        payeeRepository: (any PayeeRepository)? = nil
    ) {
        self.transactionRepository = transactionRepository
        self.accountRepository = accountRepository
        self.categoryRepository = categoryRepository
        self.payeeRepository = payeeRepository
    }

    // MARK: - Legacy compatibility

    func exportTransactionsCSV(filter: TransactionFilter?) async throws -> URL {
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

    // MARK: - CSV builder

    private func buildCSV(for transactions: [TransactionEntity]) async throws -> String {
        // Build lookup maps for human-readable names
        var accountMap: [UUID: String] = [:]
        var categoryMap: [UUID: String] = [:]
        var payeeMap: [UUID: String] = [:]

        if let accountRepo = accountRepository,
           let accounts = try? await accountRepo.fetchAll() {
            accountMap = Dictionary(uniqueKeysWithValues: accounts.map { ($0.id, $0.name) })
        }
        if let catRepo = categoryRepository,
           let categories = try? await catRepo.fetchAll() {
            categoryMap = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.name) })
        }
        if let payeeRepo = payeeRepository,
           let payees = try? await payeeRepo.fetchAll() {
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
            let note     = (tx.note ?? "").csvEscaped
            let tags     = tx.tags.joined(separator: ";").csvEscaped

            csv += "\"\(date)\",\"\(amount)\",\"\(type)\",\"\(category)\",\"\(account)\",\"\(payee)\",\"\(method)\",\"\(note)\",\"\(tags)\"\n"
        }

        return csv
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
            try data.write(to: url)
            return url
        } catch {
            throw VittoraError.exportFailed(
                String(localized: "Failed to write CSV: \(error.localizedDescription)")
            )
        }
    }
}

// MARK: - String CSV helper

private extension String {
    /// Escape double quotes by doubling them (per RFC 4180).
    var csvEscaped: String {
        replacingOccurrences(of: "\"", with: "\"\"")
    }
}

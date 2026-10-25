import Foundation
import VittoraCore

struct CSVImportPreview: Sendable {
    nonisolated let rows: [ParsedCSVTransactionRow]
    nonisolated let invalidRowCount: Int
    /// Nil for OFX and QIF, which have no columns to map.
    nonisolated let mapping: CSVColumnMapping?
}

struct CSVImportResult: Sendable, Equatable {
    nonisolated let importedCount: Int
    nonisolated let skippedDuplicateCount: Int
    nonisolated let skippedInvalidCount: Int
    nonisolated let createdPayeeCount: Int
}

enum CSVImportError: LocalizedError, Sendable {
    case emptyFile
    case unsupportedFormat
    case missingAccount

    var errorDescription: String? {
        switch self {
        case .emptyFile:
            String(localized: "The file is empty.")
        case .unsupportedFormat:
            String(localized: "We couldn't read this file with the chosen format. Check the format, or try another export from your bank.")
        case .missingAccount:
            String(localized: "Choose an account before importing.")
        }
    }
}

struct ImportTransactionsFromCSVUseCase: Sendable {
    let addTransactionUseCase: AddTransactionUseCase
    let duplicateDetectionUseCase: DuplicateDetectionUseCase
    let payeeRepository: any PayeeRepository
    let categoryRepository: any CategoryRepository

    nonisolated init(
        addTransactionUseCase: AddTransactionUseCase,
        duplicateDetectionUseCase: DuplicateDetectionUseCase,
        payeeRepository: any PayeeRepository,
        categoryRepository: any CategoryRepository
    ) {
        self.addTransactionUseCase = addTransactionUseCase
        self.duplicateDetectionUseCase = duplicateDetectionUseCase
        self.payeeRepository = payeeRepository
        self.categoryRepository = categoryRepository
    }

    nonisolated func preview(
        csvData: Data,
        profile: CSVImportProfile,
        locale: Locale = .current
    ) throws -> CSVImportPreview {
        switch profile {
        case .ofx, .qif:
            let text = try decodedText(csvData)
            let parsed = profile == .ofx
                ? StatementFileParser.parseOFX(text)
                : StatementFileParser.parseQIF(text, locale: locale)
            guard !parsed.rows.isEmpty || parsed.invalidCount > 0 else { throw CSVImportError.unsupportedFormat }
            return CSVImportPreview(rows: parsed.rows, invalidRowCount: parsed.invalidCount, mapping: nil)
        case .bankStatement:
            let grid = try parseGrid(from: csvData)
            guard let headerRow = CSVTransactionImportMapper.bankStatementHeaderRow(in: grid) else {
                throw CSVImportError.unsupportedFormat
            }
            return try previewGrid(Array(grid.dropFirst(headerRow)), profile: profile, locale: locale)
        case .generic, .mint, .ynab:
            return try previewGrid(try parseGrid(from: csvData), profile: profile, locale: locale)
        }
    }

    nonisolated private func previewGrid(
        _ grid: [[String]],
        profile: CSVImportProfile,
        locale: Locale
    ) throws -> CSVImportPreview {
        guard let headers = grid.first else { throw CSVImportError.emptyFile }
        guard let mapping = CSVTransactionImportMapper.detectMapping(headers: headers, profile: profile) else {
            throw CSVImportError.unsupportedFormat
        }
        let parsed = CSVTransactionImportMapper.parseRows(
            grid: grid,
            mapping: mapping,
            profile: profile,
            locale: locale
        )
        return CSVImportPreview(
            rows: parsed.rows,
            invalidRowCount: parsed.invalidCount,
            mapping: mapping
        )
    }

    func execute(
        csvData: Data,
        profile: CSVImportProfile,
        accountID: UUID,
        currencyCode: String,
        locale: Locale = .current
    ) async throws -> CSVImportResult {
        let preview = try preview(csvData: csvData, profile: profile, locale: locale)
        var payeesByName = try await loadPayeeLookup()
        let categoriesByName = try await loadCategoryLookup()

        var createdPayeeCount = 0
        var resolvedPayees: [Int: UUID?] = [:]
        for row in preview.rows {
            resolvedPayees[row.lineNumber] = try await resolvePayeeID(
                name: row.payeeName,
                lookup: &payeesByName,
                createdPayeeCount: &createdPayeeCount
            )
        }

        let existingTransactions = try await duplicateDetectionUseCase.prefetchExisting(
            accountID: accountID,
            covering: preview.rows.map(\.date)
        )

        var skippedDuplicateCount = 0
        var pendingTransactions: [TransactionEntity] = []
        var seenCandidates: [TransactionEntity] = existingTransactions

        for row in preview.rows {
            let payeeID = resolvedPayees[row.lineNumber] ?? nil
            let categoryID = row.categoryName.flatMap { categoriesByName[$0.lowercased()] }

            if isDuplicate(
                amount: row.amount,
                date: row.date,
                payeeID: payeeID,
                accountID: accountID,
                in: seenCandidates
            ) {
                skippedDuplicateCount += 1
                continue
            }

            let transaction = TransactionEntity(
                amount: row.amount,
                date: row.date,
                note: row.note,
                type: row.type,
                paymentMethod: .other,
                currencyCode: currencyCode,
                tags: [],
                categoryID: categoryID,
                accountID: accountID,
                payeeID: payeeID
            )
            pendingTransactions.append(transaction)
            seenCandidates.append(transaction)
        }

        if !pendingTransactions.isEmpty {
            try await addTransactionUseCase.executeBatch(pendingTransactions)
        }

        return CSVImportResult(
            importedCount: pendingTransactions.count,
            skippedDuplicateCount: skippedDuplicateCount,
            skippedInvalidCount: preview.invalidRowCount,
            createdPayeeCount: createdPayeeCount
        )
    }

    nonisolated private func decodedText(_ data: Data) throws -> String {
        guard let text = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .utf16)
            ?? String(data: data, encoding: .windowsCP1252),
            !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw CSVImportError.emptyFile
        }
        return text
    }

    nonisolated private func parseGrid(from csvData: Data) throws -> [[String]] {
        let text = try decodedText(csvData)
        let grid = CSVParser.parse(text)
        guard !grid.isEmpty else { throw CSVImportError.emptyFile }
        return grid
    }

    private func loadPayeeLookup() async throws -> [String: UUID] {
        let payees = try await payeeRepository.fetchAll()
        return Dictionary(
            payees.map { ($0.name.lowercased(), $0.id) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    private func loadCategoryLookup() async throws -> [String: UUID] {
        let categories = try await categoryRepository.fetchAll()
        return Dictionary(
            categories.map { ($0.name.lowercased(), $0.id) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    private func resolvePayeeID(
        name: String,
        lookup: inout [String: UUID],
        createdPayeeCount: inout Int
    ) async throws -> UUID? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let key = trimmed.lowercased()
        if let existing = lookup[key] {
            return existing
        }

        let entity = PayeeEntity(name: trimmed, type: .business)
        try await payeeRepository.create(entity)
        lookup[key] = entity.id
        createdPayeeCount += 1
        return entity.id
    }

    private func isDuplicate(
        amount: Decimal,
        date: Date,
        payeeID: UUID?,
        accountID: UUID,
        in candidates: [TransactionEntity]
    ) -> Bool {
        candidates.contains { transaction in
            DuplicateDetectionUseCase.matches(
                transaction,
                amount: amount,
                date: date,
                payeeID: payeeID,
                accountID: accountID
            )
        }
    }
}

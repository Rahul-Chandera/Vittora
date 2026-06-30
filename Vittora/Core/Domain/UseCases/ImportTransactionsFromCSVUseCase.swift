import Foundation
import VittoraCore

struct CSVImportPreview: Sendable {
    nonisolated let rows: [ParsedCSVTransactionRow]
    nonisolated let invalidRowCount: Int
    nonisolated let mapping: CSVColumnMapping
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
            String(localized: "The CSV file is empty.")
        case .unsupportedFormat:
            String(localized: "We couldn't recognize the column headers for this profile.")
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
        let grid = try parseGrid(from: csvData)
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
        var categoriesByName = try await loadCategoryLookup()

        var importedCount = 0
        var skippedDuplicateCount = 0
        var createdPayeeCount = 0

        for row in preview.rows {
            let payeeID = try await resolvePayeeID(
                name: row.payeeName,
                lookup: &payeesByName,
                createdPayeeCount: &createdPayeeCount
            )
            let categoryID = row.categoryName.flatMap { categoriesByName[$0.lowercased()] }

            let duplicates = try await duplicateDetectionUseCase.execute(
                amount: row.amount,
                date: row.date,
                payeeID: payeeID,
                accountID: accountID
            )
            if !duplicates.isEmpty {
                skippedDuplicateCount += 1
                continue
            }

            _ = try await addTransactionUseCase.execute(
                amount: row.amount,
                type: row.type,
                date: row.date,
                categoryID: categoryID,
                accountID: accountID,
                payeeID: payeeID,
                note: row.note,
                tags: [],
                paymentMethod: .other,
                currencyCode: currencyCode
            )
            importedCount += 1
        }

        return CSVImportResult(
            importedCount: importedCount,
            skippedDuplicateCount: skippedDuplicateCount,
            skippedInvalidCount: preview.invalidRowCount,
            createdPayeeCount: createdPayeeCount
        )
    }

    nonisolated private func parseGrid(from csvData: Data) throws -> [[String]] {
        guard let text = String(data: csvData, encoding: .utf8)
            ?? String(data: csvData, encoding: .utf16)
            ?? String(data: csvData, encoding: .windowsCP1252)
        else {
            throw CSVImportError.emptyFile
        }
        let grid = CSVParser.parse(text)
        guard !grid.isEmpty else { throw CSVImportError.emptyFile }
        return grid
    }

    private func loadPayeeLookup() async throws -> [String: UUID] {
        let payees = try await payeeRepository.fetchAll()
        return Dictionary(
            uniqueKeysWithValues: payees.map { ($0.name.lowercased(), $0.id) }
        )
    }

    private func loadCategoryLookup() async throws -> [String: UUID] {
        let categories = try await categoryRepository.fetchAll()
        return Dictionary(
            uniqueKeysWithValues: categories.map { ($0.name.lowercased(), $0.id) }
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
}

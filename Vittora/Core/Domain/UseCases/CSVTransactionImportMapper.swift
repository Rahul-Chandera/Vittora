import Foundation
import VittoraCore

enum CSVImportProfile: String, Sendable, CaseIterable, Identifiable {
    case generic
    case mint
    case ynab

    nonisolated var id: String { rawValue }

    nonisolated var displayName: String {
        switch self {
        case .generic: String(localized: "Generic CSV")
        case .mint: String(localized: "Mint")
        case .ynab: String(localized: "YNAB")
        }
    }
}

struct CSVColumnMapping: Sendable, Equatable {
    nonisolated let dateColumn: Int
    nonisolated let descriptionColumn: Int?
    nonisolated let amountColumn: Int?
    nonisolated let outflowColumn: Int?
    nonisolated let inflowColumn: Int?
    nonisolated let categoryColumn: Int?
    nonisolated let memoColumn: Int?
    nonisolated let transactionTypeColumn: Int?
}

struct ParsedCSVTransactionRow: Sendable, Identifiable {
    nonisolated var id: Int { lineNumber }
    nonisolated let lineNumber: Int
    nonisolated let date: Date
    nonisolated let amount: Decimal
    nonisolated let type: TransactionType
    nonisolated let payeeName: String
    nonisolated let note: String?
    nonisolated let categoryName: String?
}

enum CSVTransactionImportMapper {
    nonisolated static func detectMapping(headers: [String], profile: CSVImportProfile) -> CSVColumnMapping? {
        let normalized = headers.map { normalizeHeader($0) }

        switch profile {
        case .mint:
            guard let date = index(in: normalized, matchingAny: ["date"]),
                  let description = index(in: normalized, matchingAny: ["description"]),
                  let amount = index(in: normalized, matchingAny: ["amount"]),
                  let transactionType = index(in: normalized, matchingAny: ["transactiontype"])
            else { return nil }
            let category = index(in: normalized, matchingAny: ["category"])
            return CSVColumnMapping(
                dateColumn: date,
                descriptionColumn: description,
                amountColumn: amount,
                outflowColumn: nil,
                inflowColumn: nil,
                categoryColumn: category,
                memoColumn: nil,
                transactionTypeColumn: transactionType
            )

        case .ynab:
            guard let date = index(in: normalized, matchingAny: ["date"]),
                  let payee = index(in: normalized, matchingAny: ["payee"]),
                  let outflow = index(in: normalized, matchingAny: ["outflow"]),
                  let inflow = index(in: normalized, matchingAny: ["inflow"])
            else { return nil }
            let category = index(in: normalized, matchingAny: ["categorygroup/category", "category"])
            let memo = index(in: normalized, matchingAny: ["memo"])
            return CSVColumnMapping(
                dateColumn: date,
                descriptionColumn: payee,
                amountColumn: nil,
                outflowColumn: outflow,
                inflowColumn: inflow,
                categoryColumn: category,
                memoColumn: memo,
                transactionTypeColumn: nil
            )

        case .generic:
            guard let date = index(in: normalized, matchingAny: ["date", "transactiondate", "posteddate"]),
                  let amount = index(in: normalized, matchingAny: ["amount", "value", "transactionamount"])
            else { return nil }
            let description = index(
                in: normalized,
                matchingAny: ["description", "payee", "merchant", "name", "memo", "note"]
            )
            let category = index(in: normalized, matchingAny: ["category", "categoryname"])
            return CSVColumnMapping(
                dateColumn: date,
                descriptionColumn: description,
                amountColumn: amount,
                outflowColumn: nil,
                inflowColumn: nil,
                categoryColumn: category,
                memoColumn: nil,
                transactionTypeColumn: nil
            )
        }
    }

    nonisolated static func parseRows(
        grid: [[String]],
        mapping: CSVColumnMapping,
        profile: CSVImportProfile,
        locale: Locale = .current
    ) -> (rows: [ParsedCSVTransactionRow], invalidCount: Int) {
        guard grid.count > 1 else { return ([], 0) }

        var parsed: [ParsedCSVTransactionRow] = []
        var invalidCount = 0

        for (offset, columns) in grid.dropFirst().enumerated() {
            let lineNumber = offset + 2
            guard let row = parseRow(
                columns: columns,
                mapping: mapping,
                profile: profile,
                lineNumber: lineNumber,
                locale: locale
            ) else {
                invalidCount += 1
                continue
            }
            parsed.append(row)
        }

        return (parsed, invalidCount)
    }

    nonisolated private static func parseRow(
        columns: [String],
        mapping: CSVColumnMapping,
        profile: CSVImportProfile,
        lineNumber: Int,
        locale: Locale
    ) -> ParsedCSVTransactionRow? {
        guard columns.indices.contains(mapping.dateColumn) else { return nil }
        guard let date = parseDate(columns[mapping.dateColumn]) else { return nil }

        let description = mapping.descriptionColumn.flatMap { columns.indices.contains($0) ? columns[$0] : nil } ?? ""
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDescription.isEmpty else { return nil }

        let categoryName = mapping.categoryColumn.flatMap { index in
            columns.indices.contains(index) ? columns[index].trimmingCharacters(in: .whitespacesAndNewlines) : nil
        }.flatMap { $0.isEmpty ? nil : normalizedCategoryName($0) }

        let memo = mapping.memoColumn.flatMap { index in
            columns.indices.contains(index) ? columns[index].trimmingCharacters(in: .whitespacesAndNewlines) : nil
        }.flatMap { $0.isEmpty ? nil : $0 }

        let amountType: (Decimal, TransactionType)?
        if profile == .mint,
           let typeIndex = mapping.transactionTypeColumn,
           let amountIndex = mapping.amountColumn,
           columns.indices.contains(typeIndex),
           columns.indices.contains(amountIndex) {
            guard let parsedAmount = parseAmount(columns[amountIndex], locale: locale), parsedAmount != 0 else {
                return nil
            }
            let amount = abs(parsedAmount)
            guard let type = parseMintTransactionType(columns[typeIndex]) else { return nil }
            amountType = (amount, type)
        } else if profile == .ynab,
           let outflowIndex = mapping.outflowColumn,
           let inflowIndex = mapping.inflowColumn,
           columns.indices.contains(outflowIndex),
           columns.indices.contains(inflowIndex) {
            let outflow = abs(parseAmount(columns[outflowIndex], locale: locale) ?? 0)
            let inflow = abs(parseAmount(columns[inflowIndex], locale: locale) ?? 0)
            if outflow > 0 {
                amountType = (outflow, .expense)
            } else if inflow > 0 {
                amountType = (inflow, .income)
            } else {
                return nil
            }
        } else if let amountIndex = mapping.amountColumn, columns.indices.contains(amountIndex) {
            guard let signed = parseAmount(columns[amountIndex], locale: locale), signed != 0 else { return nil }
            if signed < 0 {
                amountType = (-signed, .expense)
            } else {
                amountType = (signed, .income)
            }
        } else {
            return nil
        }

        guard let (amount, type) = amountType, amount > 0 else { return nil }

        return ParsedCSVTransactionRow(
            lineNumber: lineNumber,
            date: date,
            amount: amount,
            type: type,
            payeeName: trimmedDescription,
            note: memo,
            categoryName: categoryName
        )
    }

    nonisolated private static func parseMintTransactionType(_ raw: String) -> TransactionType? {
        switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "debit", "expense", "withdrawal", "payment":
            return .expense
        case "credit", "income", "deposit":
            return .income
        default:
            return nil
        }
    }

    nonisolated private static func parseAmount(_ raw: String, locale: Locale) -> Decimal? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.hasPrefix("("), trimmed.hasSuffix(")") {
            let inner = trimmed.dropFirst().dropLast().trimmingCharacters(in: .whitespacesAndNewlines)
            guard let magnitude = parseUnsignedAmount(inner, locale: locale), magnitude != 0 else { return nil }
            return -magnitude
        }

        return parseUnsignedAmount(trimmed, locale: locale)
    }

    nonisolated private static func parseUnsignedAmount(_ raw: String, locale: Locale) -> Decimal? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.generatesDecimalNumbers = true
        if let number = formatter.number(from: trimmed) {
            return number.decimalValue
        }

        let normalized = trimmed
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: "₹", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Decimal(string: normalized)
    }

    nonisolated private static func parseDate(_ raw: String) -> Date? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let formats = [
            "yyyy-MM-dd",
            "MM/dd/yyyy",
            "M/d/yyyy",
            "dd/MM/yyyy",
            "d/M/yyyy",
            "yyyy/MM/dd",
            "MMM d, yyyy",
            "MMM dd, yyyy",
        ]

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)

        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: trimmed) {
                return date
            }
        }
        return nil
    }

    nonisolated private static func normalizeHeader(_ header: String) -> String {
        header
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "_", with: "")
    }

    nonisolated private static func index(in headers: [String], matchingAny candidates: [String]) -> Int? {
        headers.firstIndex { header in
            candidates.contains { candidate in
                header == candidate || header.contains(candidate)
            }
        }
    }

    nonisolated private static func normalizedCategoryName(_ raw: String) -> String {
        if let separator = raw.firstIndex(of: ":") {
            let suffix = raw[raw.index(after: separator)...].trimmingCharacters(in: .whitespacesAndNewlines)
            if !suffix.isEmpty { return suffix }
        }
        return raw
    }
}

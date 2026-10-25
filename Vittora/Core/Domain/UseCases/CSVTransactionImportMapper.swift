import Foundation
import VittoraCore

enum CSVImportProfile: String, Sendable, CaseIterable, Identifiable {
    case generic
    case bankStatement
    case ofx
    case qif
    case mint
    case ynab

    nonisolated var id: String { rawValue }

    nonisolated var displayName: String {
        switch self {
        case .generic: String(localized: "Generic CSV")
        case .bankStatement: String(localized: "Bank statement (CSV)")
        case .ofx: String(localized: "OFX / QFX")
        case .qif: String(localized: "QIF")
        case .mint: String(localized: "Mint")
        case .ynab: String(localized: "YNAB")
        }
    }

    /// The profile a file's extension settles on its own; nil for CSV, where the
    /// columns decide.
    nonisolated static func forFileExtension(_ fileExtension: String) -> CSVImportProfile? {
        switch fileExtension.lowercased() {
        case "ofx", "qfx": .ofx
        case "qif": .qif
        default: nil
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

        case .bankStatement:
            // Statement exports from banks (HDFC, ICICI, SBI, Axis and most others) split
            // money out and money in into two columns. Candidates are in priority order:
            // ICICI lists "Value Date" before "Transaction Date", and the transaction
            // date is the one that matters.
            guard let date = preferredIndex(in: normalized, candidates: ["transactiondate", "txndate", "trandate", "date", "valuedate", "valuedt"]),
                  let description = preferredIndex(in: normalized, candidates: ["narration", "transactionremarks", "particulars", "description", "remarks", "details"]),
                  let outflow = preferredIndex(in: normalized, candidates: ["withdrawalamt", "withdrawal", "debitamount", "debit", "=dr", "=dr."]),
                  let inflow = preferredIndex(in: normalized, candidates: ["depositamt", "deposit", "creditamount", "credit", "=cr", "=cr."])
            else { return nil }
            return CSVColumnMapping(
                dateColumn: date,
                descriptionColumn: description,
                amountColumn: nil,
                outflowColumn: outflow,
                inflowColumn: inflow,
                categoryColumn: nil,
                memoColumn: nil,
                transactionTypeColumn: nil
            )

        case .ofx, .qif:
            return nil

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
        let dayFirst = slashDatesAreDayFirst(
            grid.dropFirst().compactMap { $0.indices.contains(mapping.dateColumn) ? $0[mapping.dateColumn] : nil },
            locale: locale
        )

        for (offset, columns) in grid.dropFirst().enumerated() {
            let lineNumber = offset + 2
            guard let row = parseRow(
                columns: columns,
                mapping: mapping,
                profile: profile,
                lineNumber: lineNumber,
                locale: locale,
                dayFirst: dayFirst
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
        locale: Locale,
        dayFirst: Bool
    ) -> ParsedCSVTransactionRow? {
        guard columns.indices.contains(mapping.dateColumn) else { return nil }
        guard let date = parseDate(columns[mapping.dateColumn], dayFirst: dayFirst) else { return nil }

        let description = mapping.descriptionColumn.flatMap { columns.indices.contains($0) ? columns[$0] : nil } ?? ""
        let rawDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = profile == .bankStatement ? cleanedBankNarration(rawDescription) : rawDescription
        guard !trimmedDescription.isEmpty else { return nil }
        if profile == .ynab, isYNABNonSpendingPayee(trimmedDescription) { return nil }

        let categoryName = mapping.categoryColumn.flatMap { index in
            columns.indices.contains(index) ? columns[index].trimmingCharacters(in: .whitespacesAndNewlines) : nil
        }.flatMap { raw -> String? in
            guard !raw.isEmpty else { return nil }
            // YNAB files income under "Inflow: Ready to Assign", a budgeting
            // bucket rather than a category; importing it made a category
            // called "Ready to Assign".
            if profile == .ynab, raw.lowercased().hasPrefix("inflow:") { return nil }
            return normalizedCategoryName(raw)
        }

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
        } else if profile == .ynab || profile == .bankStatement,
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
            // The full narration stays in the note when the payee is a cleaned-up part of it.
            note: memo ?? (trimmedDescription == rawDescription ? nil : rawDescription),
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

    /// Rows YNAB exports that are not spending or income.
    ///
    /// YNAB writes a transfer once per account ("Transfer : Savings"), so
    /// importing both legs counted the same money as an expense on one side and
    /// income on the other. A CSV import cannot map the second account a Vittora
    /// transfer needs, so the legs are skipped. "Starting Balance" is an opening
    /// balance, not income.
    nonisolated static func isYNABNonSpendingPayee(_ payee: String) -> Bool {
        let lowered = payee.lowercased()
        return lowered.hasPrefix("transfer :") || lowered == "starting balance"
    }

    /// Whether this file writes slash dates day first (05/01/2026 = 5 January).
    ///
    /// One unambiguous row, a first number over 12 or a second over 12, settles
    /// it for the whole file; with none, the user's locale decides. Trying
    /// month-first on every row on its own turned 05/01/2026 into 1 May in a UK or
    /// Indian YNAB export, silently.
    nonisolated static func slashDatesAreDayFirst(_ values: [String], locale: Locale) -> Bool {
        for raw in values {
            // Slash or dash, four- or two-digit year (bank statements write 25/10/26).
            // An ISO date's first part is the year, so it is skipped.
            let parts = raw.trimmingCharacters(in: .whitespacesAndNewlines).split(whereSeparator: { $0 == "/" || $0 == "-" })
            guard parts.count == 3, parts[0].count <= 2, parts[2].count == 4 || parts[2].count == 2,
                  let first = Int(parts[0]), let second = Int(parts[1]) else { continue }
            if first > 12 { return true }
            if second > 12 { return false }
        }
        let order = DateFormatter.dateFormat(fromTemplate: "MMdd", options: 0, locale: locale) ?? "MM/dd"
        return order.hasPrefix("d")
    }

    nonisolated private static func parseDate(_ raw: String, dayFirst: Bool) -> Date? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Four-digit years before two-digit ones: "yy" would also accept "2026".
        let numericFormats = dayFirst
            ? ["dd/MM/yyyy", "d/M/yyyy", "dd-MM-yyyy", "d-M-yyyy", "dd/MM/yy", "d/M/yy", "dd-MM-yy"]
            : ["MM/dd/yyyy", "M/d/yyyy", "MM-dd-yyyy", "MM/dd/yy", "M/d/yy"]
        let formats = ["yyyy-MM-dd"] + numericFormats + [
            "yyyy/MM/dd",
            "MMM d, yyyy",
            "MMM dd, yyyy",
            "dd-MMM-yyyy",
            "d-MMM-yyyy",
            "dd MMM yyyy",
            "d MMM yyyy",
            "dd-MMM-yy",
            "dd MMM yy",
        ]

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)

        for format in formatsMatchingYearLength(formats, value: trimmed) {
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

    /// Keeps only the formats whose year has as many digits as the value's. DateFormatter's
    /// "yyyy" accepts "26" as the year 0026, and "yy" accepts "2026", so trying both on
    /// "25/10/26" read it as the 26th of October in year 25.
    nonisolated static func formatsMatchingYearLength(_ formats: [String], value: String) -> [String] {
        // An ISO date ends in two digits too (the day), so a leading four-digit year rules it out.
        let twoDigitYear = value.range(of: #"^\d{4}"#, options: .regularExpression) == nil
            && value.range(of: #"[/\- ]\d{2}$"#, options: .regularExpression) != nil
        return formats.filter { format in
            let fourDigit = format.contains("yyyy")
            return twoDigitYear ? !fourDigit : (fourDigit || !format.contains("yy"))
        }
    }

    /// The header matching the earliest candidate, so candidate order is priority order.
    /// A candidate starting with "=" must match the whole header: "dr" and "cr" would
    /// otherwise match inside "description" and "credit".
    nonisolated private static func preferredIndex(in headers: [String], candidates: [String]) -> Int? {
        for candidate in candidates {
            if candidate.hasPrefix("=") {
                if let match = headers.firstIndex(of: String(candidate.dropFirst())) { return match }
            } else if let match = headers.firstIndex(where: { $0 == candidate || $0.contains(candidate) }) {
                return match
            }
        }
        return nil
    }

    /// The row a bank statement's column headers sit on. Statement exports usually open
    /// with account details, an address and the statement period before the table.
    nonisolated static func bankStatementHeaderRow(in grid: [[String]]) -> Int? {
        grid.prefix(40).firstIndex { detectMapping(headers: $0, profile: .bankStatement) != nil }
    }

    /// A readable payee from a bank narration, which packs references around the name:
    /// "UPI-SWIGGY-swiggy@axisbank-UTIB0000100-629812345678-PAYMENT" → "SWIGGY",
    /// "UPI/629812345678/Payment/swiggy@axis/Axis Bank" → "Swiggy",
    /// "POS 416021XXXXXX1234 AMAZON PAY INDI" → "AMAZON PAY INDI".
    /// Falls back to the narration itself when nothing better stands out.
    nonisolated static func cleanedBankNarration(_ narration: String) -> String {
        let trimmed = narration.trimmingCharacters(in: .whitespacesAndNewlines)
        let upper = trimmed.uppercased()
        let leadingNoise = ["BY TRANSFER", "TO TRANSFER", "POS", "ECOM", "ATW", "NWD", "NEFT DR", "NEFT CR", "IMPS", "NEFT", "RTGS"]
        let noiseWords: Set<String> = ["UPI", "DR", "CR", "P2M", "P2A", "PAYMENT", "PAY", "TRANSFER", "SENT", "RECEIVED", "UPIINTENT", "BY", "TO"]

        let tokens = trimmed
            .split(whereSeparator: { $0 == "-" || $0 == "/" })
            .map { $0.trimmingCharacters(in: .whitespaces) }
        func isNoise(_ token: String) -> Bool {
            let value = token.uppercased()
            if value.isEmpty || noiseWords.contains(value) || leadingNoise.contains(value) { return true }
            if value.contains("@") { return true }
            if value.filter(\.isLetter).count < 3 { return true }                       // refs, masked numbers
            if value.range(of: #"^[A-Z]{4}0[A-Z0-9]{6}$"#, options: .regularExpression) != nil { return true } // IFSC
            if value.range(of: #"\d{6,}|X{3,}\d"#, options: .regularExpression) != nil, value.contains(" ") == false { return true }
            return false
        }

        if upper.hasPrefix("UPI") || upper.contains("/UPI") || upper.contains("-UPI") || upper.contains("NEFT") || upper.contains("IMPS") || upper.contains("RTGS") {
            // With a UPI handle in the narration, the name comes before it; what follows
            // is usually the payee's bank ("…/swiggy@axis/Axis Bank").
            let vpaIndex = tokens.firstIndex { $0.contains("@") }
            let candidates = vpaIndex.map { Array(tokens[..<$0]) } ?? tokens
            if let name = candidates.first(where: { !isNoise($0) }) {
                return stripLeadingNoise(name, noise: leadingNoise)
            }
            if let vpaIndex, let handle = tokens[vpaIndex].split(separator: "@").first, handle.count >= 3 {
                return handle.prefix(1).uppercased() + handle.dropFirst().lowercased()
            }
        }
        for prefix in ["POS ", "ECOM ", "ATW ", "NWD "] where upper.hasPrefix(prefix) {
            let rest = trimmed.dropFirst(prefix.count)
                .split(separator: " ")
                .filter { $0.range(of: #"\d{4,}|X{3,}"#, options: .regularExpression) == nil }
                .joined(separator: " ")
            if rest.count >= 3 { return rest }
        }
        return trimmed
    }

    nonisolated private static func stripLeadingNoise(_ value: String, noise: [String]) -> String {
        for prefix in noise where value.uppercased().hasPrefix(prefix + " ") {
            return String(value.dropFirst(prefix.count + 1)).trimmingCharacters(in: .whitespaces)
        }
        return value
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

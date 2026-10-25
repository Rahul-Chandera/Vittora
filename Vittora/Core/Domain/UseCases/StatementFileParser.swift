import Foundation
import VittoraCore

/// Reads bank statement files that are not CSV, into the same rows the CSV import
/// produces: OFX and QFX (most US banks and Quicken), and QIF (Quicken, older exports).
///
/// Parsing happens on the device. Nothing in these formats needs a bank connection:
/// the user downloads the file from their bank and picks it here.
enum StatementFileParser {

    // MARK: - OFX / QFX

    /// OFX 1.x is SGML (leaf tags are never closed) and OFX 2.x is XML. Reading each
    /// `<STMTTRN>` block and taking a leaf's text up to the next `<` handles both.
    nonisolated static func parseOFX(_ text: String) -> (rows: [ParsedCSVTransactionRow], invalidCount: Int) {
        let blocks = text.components(separatedBy: "<STMTTRN>").dropFirst()
        var rows: [ParsedCSVTransactionRow] = []
        var invalid = 0
        for (index, rawBlock) in blocks.enumerated() {
            let block = rawBlock.components(separatedBy: "</STMTTRN>").first ?? rawBlock
            guard let date = ofxDate(leaf("DTPOSTED", in: block) ?? leaf("DTUSER", in: block)),
                  let signed = ofxAmount(leaf("TRNAMT", in: block)),
                  signed != 0
            else {
                invalid += 1
                continue
            }
            let name = leaf("NAME", in: block) ?? leaf("PAYEE", in: block)
            let memo = leaf("MEMO", in: block)
            rows.append(ParsedCSVTransactionRow(
                lineNumber: index + 1,
                date: date,
                amount: abs(signed),
                type: signed < 0 ? .expense : .income,
                payeeName: name ?? memo ?? "",
                note: name == nil ? nil : memo,
                categoryName: nil
            ))
        }
        return (rows, invalid)
    }

    nonisolated private static func leaf(_ tag: String, in block: String) -> String? {
        guard let start = block.range(of: "<\(tag)>", options: .caseInsensitive) else { return nil }
        let rest = block[start.upperBound...]
        let value = rest.prefix { $0 != "<" && $0 != "\n" && $0 != "\r" }
        let decoded = value
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .trimmingCharacters(in: .whitespaces)
        return decoded.isEmpty ? nil : decoded
    }

    /// "20261025", "20261025120000", "20261025120000.000[-5:EST]": the date is the
    /// first eight digits.
    nonisolated private static func ofxDate(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        let digits = raw.prefix(8)
        guard digits.count == 8, digits.allSatisfy(\.isNumber) else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd"
        return formatter.date(from: String(digits))
    }

    /// Signed, with "." or, from some European banks, "," as the decimal mark.
    nonisolated private static func ofxAmount(_ raw: String?) -> Decimal? {
        guard var value = raw?.replacingOccurrences(of: " ", with: "") else { return nil }
        if !value.contains("."), value.contains(",") {
            value = value.replacingOccurrences(of: ",", with: ".")
        } else {
            value = value.replacingOccurrences(of: ",", with: "")
        }
        return Decimal(string: value, locale: Locale(identifier: "en_US_POSIX"))
    }

    // MARK: - QIF

    /// One transaction per record, records ending in `^`. D date, T (or U) amount,
    /// P payee, M memo, L category. Lines starting with `!` declare the account type.
    nonisolated static func parseQIF(_ text: String, locale: Locale = .current) -> (rows: [ParsedCSVTransactionRow], invalidCount: Int) {
        var records: [[Character: String]] = []
        var current: [Character: String] = [:]
        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard let code = line.first, !line.hasPrefix("!") else { continue }
            if code == "^" {
                if !current.isEmpty { records.append(current) }
                current = [:]
                continue
            }
            let value = String(line.dropFirst()).trimmingCharacters(in: .whitespaces)
            // Split lines (S/E/$) repeat; the first D, T, P, M, L of a record are the ones that matter.
            if current[code] == nil { current[code] = value }
        }
        if !current.isEmpty { records.append(current) }

        let dates = records.compactMap { $0["D"].map(normalizedQIFDate) }
        let dayFirst = CSVTransactionImportMapper.slashDatesAreDayFirst(dates, locale: locale)

        var rows: [ParsedCSVTransactionRow] = []
        var invalid = 0
        for (index, record) in records.enumerated() {
            guard let rawDate = record["D"],
                  let date = qifDate(normalizedQIFDate(rawDate), dayFirst: dayFirst),
                  let rawAmount = record["T"] ?? record["U"],
                  let signed = qifAmount(rawAmount),
                  signed != 0
            else {
                invalid += 1
                continue
            }
            let payee = record["P"].flatMap { $0.isEmpty ? nil : $0 }
            let memo = record["M"].flatMap { $0.isEmpty ? nil : $0 }
            let category = record["L"].flatMap { raw -> String? in
                // [Account] is a transfer target, not a category.
                guard !raw.isEmpty, !raw.hasPrefix("[") else { return nil }
                return raw.split(separator: ":").last.map(String.init)
            }
            rows.append(ParsedCSVTransactionRow(
                lineNumber: index + 1,
                date: date,
                amount: abs(signed),
                type: signed < 0 ? .expense : .income,
                payeeName: payee ?? memo ?? "",
                note: payee == nil ? nil : memo,
                categoryName: category
            ))
        }
        return (rows, invalid)
    }

    /// Quicken writes the year after an apostrophe for 2000 onwards: "10/25'26".
    nonisolated private static func normalizedQIFDate(_ raw: String) -> String {
        raw.replacingOccurrences(of: "'", with: "/").replacingOccurrences(of: " ", with: "")
    }

    nonisolated private static func qifDate(_ value: String, dayFirst: Bool) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        let numeric = dayFirst
            ? ["dd/MM/yyyy", "d/M/yyyy", "dd/MM/yy", "d/M/yy"]
            : ["MM/dd/yyyy", "M/d/yyyy", "MM/dd/yy", "M/d/yy"]
        let formats = CSVTransactionImportMapper.formatsMatchingYearLength(
            ["yyyy-MM-dd"] + numeric + ["dd-MM-yyyy", "dd.MM.yyyy"], value: value
        )
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: value) { return date }
        }
        return nil
    }

    nonisolated private static func qifAmount(_ raw: String) -> Decimal? {
        let cleaned = raw.replacingOccurrences(of: ",", with: "").replacingOccurrences(of: " ", with: "")
        return Decimal(string: cleaned, locale: Locale(identifier: "en_US_POSIX"))
    }
}

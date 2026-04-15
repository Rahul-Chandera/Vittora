import Foundation

struct ReceiptParserService: Sendable {
    nonisolated init() {}

    nonisolated func parse(blocks: [RecognizedTextBlock]) -> ReceiptData {
        let lines = blocks.map(\.text)
        let rawText = lines.joined(separator: "\n")

        let totalAmount = extractAmount(from: lines)
        let date = extractDate(from: lines)
        let merchantName = extractMerchant(from: lines)
        let lineItems = extractLineItems(from: lines)

        return ReceiptData(
            totalAmount: totalAmount,
            date: date,
            merchantName: merchantName,
            lineItems: lineItems,
            rawText: rawText
        )
    }

    // MARK: - Amount extraction

    private nonisolated func extractAmount(from lines: [String]) -> Decimal? {
        // Prefer lines with "total", "amount due", "grand total"
        let totalKeywords = ["grand total", "total due", "amount due", "total amount", "total"]
        for keyword in totalKeywords {
            for line in lines where line.lowercased().contains(keyword) {
                if let amount = parseAmount(from: line) {
                    return amount
                }
            }
        }
        // Fallback: last monetary value in receipt
        return lines.reversed().compactMap { parseAmount(from: $0) }.first
    }

    private nonisolated func parseAmount(from text: String) -> Decimal? {
        // Patterns: $XX.XX, Rs. X,XXX, INR X,XXX.XX, plain XX.XX
        let patterns = [
            #"\$\s*(\d{1,3}(?:,\d{3})*(?:\.\d{2})?)"#,
            #"(?:Rs\.?|INR)\s*(\d{1,3}(?:,\d{3})*(?:\.\d{2})?)"#,
            #"(\d{1,3}(?:,\d{3})*\.\d{2})"#
        ]
        for pattern in patterns {
            if let match = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
                .firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               match.numberOfRanges > 1,
               let range = Range(match.range(at: 1), in: text) {
                let numStr = text[range].replacingOccurrences(of: ",", with: "")
                return Decimal(string: numStr)
            }
        }
        return nil
    }

    // MARK: - Date extraction

    private nonisolated func extractDate(from lines: [String]) -> Date? {
        let patterns: [(pattern: String, format: String)] = [
            (#"\d{2}/\d{2}/\d{4}"#, "MM/dd/yyyy"),
            (#"\d{2}-\d{2}-\d{4}"#, "dd-MM-yyyy"),
            (#"\d{4}-\d{2}-\d{2}"#, "yyyy-MM-dd"),
            (#"\d{1,2}\s+(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+\d{4}"#, "dd MMM yyyy")
        ]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        for line in lines {
            for (pattern, format) in patterns {
                if let match = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
                    .firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
                   let range = Range(match.range, in: line) {
                    formatter.dateFormat = format
                    if let date = formatter.date(from: String(line[range])) {
                        return date
                    }
                }
            }
        }
        return nil
    }

    // MARK: - Merchant extraction

    private nonisolated func extractMerchant(from lines: [String]) -> String? {
        // The merchant name is typically one of the first non-empty lines
        let candidates = lines
            .prefix(5)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && $0.count > 2 && !containsOnlyNumbers($0) }
        return candidates.first
    }

    private nonisolated func containsOnlyNumbers(_ text: String) -> Bool {
        text.allSatisfy { $0.isNumber || $0 == "." || $0 == "," || $0 == "-" }
    }

    // MARK: - Line items extraction

    private nonisolated func extractLineItems(from lines: [String]) -> [(name: String, amount: Decimal)] {
        var items: [(name: String, amount: Decimal)] = []
        // Look for lines with item name + price pattern
        let pattern = #"^(.+?)\s+\$?\s*(\d+\.\d{2})\s*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        for line in lines {
            let range = NSRange(line.startIndex..., in: line)
            if let match = regex.firstMatch(in: line, range: range),
               match.numberOfRanges == 3,
               let nameRange = Range(match.range(at: 1), in: line),
               let amountRange = Range(match.range(at: 2), in: line),
               let amount = Decimal(string: String(line[amountRange])) {
                let name = String(line[nameRange]).trimmingCharacters(in: .whitespaces)
                items.append((name: name, amount: amount))
            }
        }
        return items
    }
}

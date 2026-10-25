import Foundation

/// A spending alert from a bank, card issuer or UPI app, reduced to what an expense needs.
public struct BankMessageDebit: Equatable, Sendable {
    public nonisolated let amount: Decimal
    public nonisolated let currencyCode: String
    public nonisolated let merchant: String?
    public nonisolated let paymentMethod: PaymentMethod?

    public nonisolated init(amount: Decimal, currencyCode: String, merchant: String?, paymentMethod: PaymentMethod?) {
        self.amount = amount
        self.currencyCode = currencyCode
        self.merchant = merchant
        self.paymentMethod = paymentMethod
    }
}

/// Reads a bank or UPI debit alert on the device. The text reaches it only through a
/// Shortcuts automation the user sets up themselves: Vittora never reads messages.
///
/// It only returns money that has already left: credits, OTPs, upcoming autopay notices,
/// collect requests, declines and refunds return nil, and so do ATM withdrawals, which
/// move money into cash rather than spend it. When in doubt it returns nil: a missed
/// alert costs the user one manual entry, a wrong one puts money in the ledger that was
/// never spent.
public enum BankMessageParser {
    public nonisolated static func parseDebit(_ message: String) -> BankMessageDebit? {
        let text = message.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        let lower = text.lowercased()

        let notSpending = [
            "one time password", "one-time password", "verification code",
            "will be debited", "to be debited", "is due", "due on", "due date",
            "collect request", "requested", "declined", "failed", "reversed", "refund",
            "cash withdrawal",
        ]
        guard !notSpending.contains(where: lower.contains),
              firstMatch(#"\b(otp|atm)\b"#, in: lower) == nil
        else { return nil }

        // "Paid" and "transaction" also appear in credit alerts ("paid by", "transaction
        // of ... credited"), so they only count when the message is not a credit.
        let strongDebit = ["debited", "spent", "sent ", "purchase", "withdrawn", "charged", "charge of"]
        let weakDebit = ["paid", "transaction"]
        let isStrong = strongDebit.contains(where: lower.contains)
        guard isStrong || weakDebit.contains(where: lower.contains) else { return nil }
        if !isStrong, lower.contains("credited") || lower.contains("received") { return nil }

        guard let (amount, currency) = amountAndCurrency(in: text) else { return nil }
        return BankMessageDebit(
            amount: amount,
            currencyCode: currency,
            merchant: merchant(in: text),
            paymentMethod: paymentMethod(in: lower)
        )
    }

    // MARK: - Amount

    private nonisolated static let currencyCodes: [String: String] = [
        "rs": "INR", "rs.": "INR", "inr": "INR", "₹": "INR",
        "$": "USD", "usd": "USD", "us$": "USD",
        "€": "EUR", "eur": "EUR", "£": "GBP", "gbp": "GBP",
    ]

    /// The first amount next to a currency marker. Debit alerts lead with the amount
    /// spent; the available balance, when present, comes after it.
    private nonisolated static func amountAndCurrency(in text: String) -> (Decimal, String)? {
        let marker = #"(rs\.?|inr|₹|us\$|usd|\$|€|eur|£|gbp)"#
        let number = #"([0-9][0-9,]*(?:\.[0-9]{1,2})?)"#
        for (pattern, markerFirst) in [(marker + #"\s?"# + number, true), (number + #"\s?"# + marker, false)] {
            guard let match = firstMatch(pattern, in: text) else { continue }
            let rawMarker = match[markerFirst ? 0 : 1].lowercased()
            let rawNumber = match[markerFirst ? 1 : 0].replacingOccurrences(of: ",", with: "")
            guard let code = currencyCodes[rawMarker],
                  let amount = Decimal(string: rawNumber, locale: Locale(identifier: "en_US_POSIX")),
                  amount > 0
            else { continue }
            return (amount, code)
        }
        return nil
    }

    // MARK: - Merchant

    private nonisolated static let merchantEnd = #"(?=\s+on\b|\s+ref|\s+via\b|\s+using\b|\s+avl|\s+bal|\s+txn|\s+upi|\s+was\b|\s+from\b|[.,;:()]|$)"#

    private nonisolated static func merchant(in text: String) -> String? {
        if let handle = firstMatch(#"vpa\s+([a-z0-9._\-]+)@[a-z0-9.\-]+"#, in: text)?.first {
            return humanized(handle)
        }
        for lead in ["at", "with", "to", "info"] {
            let pattern = #"\b"# + lead + #"[:\s]+([^.,;:()]+?)"# + merchantEnd
            for candidate in allMatches(pattern, in: text) {
                if let name = cleaned(candidate) { return name }
            }
        }
        // ICICI-style: "...debited for Rs 300.00 on 25-Oct-26; Zomato credited."
        for candidate in allMatches(#"[;.]\s*([^.;:()]+?)\s+credited\b"#, in: text) {
            if let name = cleaned(candidate) { return name }
        }
        return nil
    }

    /// Rejects what follows "to" or "at" when it is the user's own account or a time,
    /// not a merchant: "credited to a/c no. XX5678", "at 8:14 AM".
    private nonisolated static func cleaned(_ raw: String) -> String? {
        let name = raw.trimmingCharacters(in: .whitespaces)
        let lower = name.lowercased()
        let accountish = ["a/c", "ac ", "acct", "account", "your ", "you ", "xx", "card", "beneficiary", "mobile"]
        guard name.count >= 2, name.count <= 40,
              !accountish.contains(where: lower.hasPrefix),
              firstMatch(#"^\d|x{2,}\d|\*+\d{2,}|\d{4,}"#, in: lower) == nil
        else { return nil }
        return name
    }

    /// "swiggy" → "Swiggy", "big.basket" → "Big Basket". UPI handles are lowercase
    /// identifiers; a readable name matches more payees and rules.
    private nonisolated static func humanized(_ handle: String) -> String? {
        let words = handle.split(whereSeparator: { "._-".contains($0) })
        guard !words.isEmpty else { return nil }
        let name = words.map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
        return cleaned(name) ?? name
    }

    // MARK: - Payment method

    private nonisolated static func paymentMethod(in lower: String) -> PaymentMethod? {
        if lower.contains("upi") || lower.contains("vpa") { return .upi }
        if lower.contains("credit card") { return .creditCard }
        if lower.contains("debit card") { return .debitCard }
        if ["neft", "imps", "rtgs"].contains(where: lower.contains) { return .bankTransfer }
        return nil
    }

    // MARK: - Regex helpers

    private nonisolated static func firstMatch(_ pattern: String, in text: String) -> [String]? {
        allCaptureGroups(pattern, in: text).first
    }

    private nonisolated static func allMatches(_ pattern: String, in text: String) -> [String] {
        allCaptureGroups(pattern, in: text).compactMap(\.first)
    }

    private nonisolated static func allCaptureGroups(_ pattern: String, in text: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).map { match in
            (1..<max(1, match.numberOfRanges)).compactMap { index in
                Range(match.range(at: index), in: text).map { String(text[$0]) }
            }
        }
    }
}

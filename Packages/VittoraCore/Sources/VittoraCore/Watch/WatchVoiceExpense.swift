import Foundation

/// Voice entry on Apple Watch (M2.6.2): turns "500 for groceries" into an
/// amount and the words that name a category.
///
/// Shared by the watch — which parses what the user dictated or told Siri — and
/// the phone, which matches a category the watch could not. The watch only
/// carries the eight most-used categories, so "groceries" often has no local
/// match; the phrase travels with the expense and the phone, which knows every
/// category, resolves it.
public struct WatchVoiceExpense: Equatable, Sendable {
    /// Nil when nothing in the phrase was a usable amount.
    public var amount: Decimal?
    /// What is left once the amount and filler words are removed, e.g.
    /// "groceries". Empty when the user said only an amount.
    public var categoryPhrase: String

    public init(amount: Decimal?, categoryPhrase: String) {
        self.amount = amount
        self.categoryPhrase = categoryPhrase
    }

    /// Larger than the Digital Crown's ceiling on purpose: the crown stops at
    /// 10,000 so it stays usable, but a spoken "50000 for rent" in rupees is
    /// an ordinary expense.
    public static let maximumAmount: Decimal = 10_000_000

    /// Words that carry no meaning for the expense. Dictation arrives in the
    /// user's language, so the three the app ships in are covered. Not shown
    /// to anyone, so not localized.
    static let fillerWords: Set<String> = [
        // English
        "add", "added", "log", "spent", "spend", "paid", "pay", "i", "for", "on", "at", "in",
        "a", "an", "the", "of", "my", "to", "expense", "and",
        // Currency words dictation writes out
        "dollar", "dollars", "buck", "bucks", "rupee", "rupees", "rs", "inr", "usd",
        "euro", "euros", "pound", "pounds", "gbp", "eur", "cad", "aud",
        // Spanish
        "añadir", "añade", "agrega", "agregar", "gasté", "pagué", "para", "en", "de", "el",
        "la", "los", "las", "un", "una", "por", "gasto", "pesos", "peso",
        // Hindi
        "के", "लिए", "पर", "में", "का", "की", "जोड़ें", "जोड़ो", "खर्च", "रुपये", "रुपए", "रुपया",
    ]

    private static let currencySymbols = CharacterSet(charactersIn: "$₹€£¥")

    public static func parse(_ text: String, locale: Locale = .current) -> WatchVoiceExpense {
        var amount: Decimal?
        var words: [String] = []
        for rawToken in text.split(whereSeparator: \.isWhitespace) {
            let token = String(rawToken)
                .trimmingCharacters(in: currencySymbols)
                .trimmingCharacters(in: .punctuationCharacters.subtracting(CharacterSet(charactersIn: ".,")))
                .trimmingCharacters(in: CharacterSet(charactersIn: ".,"))
            guard !token.isEmpty else { continue }
            // The first number is the amount; any later one is part of the
            // description ("2 coffees") and is left alone.
            if amount == nil, let value = parseAmount(token, locale: locale) {
                amount = value
                continue
            }
            if fillerWords.contains(token.lowercased()) { continue }
            words.append(token)
        }
        return WatchVoiceExpense(amount: amount, categoryPhrase: words.joined(separator: " "))
    }

    /// A positive amount with at most two decimal places, read in the user's
    /// locale first ("12,50" in Spanish) and then as plain digits.
    static func parseAmount(_ token: String, locale: Locale) -> Decimal? {
        guard token.contains(where: \.isNumber) else { return nil }
        for candidateLocale in [locale, Locale(identifier: "en_US_POSIX")] {
            let formatter = NumberFormatter()
            formatter.locale = candidateLocale
            formatter.numberStyle = .decimal
            formatter.generatesDecimalNumbers = true
            guard let value = formatter.number(from: token)?.decimalValue,
                  value > 0, value <= maximumAmount else { continue }
            var scaled = value * 100
            var rounded = Decimal()
            NSDecimalRound(&rounded, &scaled, 0, .plain)
            guard rounded == scaled else { continue }
            return value
        }
        return nil
    }

    /// The candidate whose name best matches what was said, or nil.
    ///
    /// Exact name first, then singular/plural ("grocery" for "Groceries"),
    /// then a whole-word match either way ("food" finds "Food & Dining";
    /// "coffee at starbucks" finds "Coffee"). Case- and accent-insensitive.
    /// Never guesses from a partial word — "gas" must not become "Gasoline
    /// Tax Refund" by prefix — because a wrong category is worse than none.
    public static func matchCategory<Candidate>(
        _ phrase: String,
        in candidates: [Candidate],
        name: (Candidate) -> String
    ) -> Candidate? {
        let spoken = normalizedWords(phrase)
        guard !spoken.isEmpty else { return nil }
        let spokenStems = Set(spoken.map(stem))

        var best: (candidate: Candidate, score: Int)?
        for candidate in candidates {
            let nameWords = normalizedWords(name(candidate))
            guard !nameWords.isEmpty else { continue }
            let nameStems = nameWords.map(stem)
            let score: Int
            if nameWords == spoken {
                score = 3
            } else if nameStems == spoken.map(stem) {
                score = 2
            } else if nameStems.allSatisfy(spokenStems.contains) || Set(nameStems).isSuperset(of: spokenStems) {
                score = 1
            } else {
                continue
            }
            if score > (best?.score ?? 0) { best = (candidate, score) }
        }
        return best?.candidate
    }

    private static func normalizedWords(_ text: String) -> [String] {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty && !fillerWords.contains($0) }
    }

    /// Crude plural folding — enough for category names, which are short and
    /// mostly regular ("groceries" → "grocery", "bills" → "bill").
    private static func stem(_ word: String) -> String {
        if word.hasSuffix("ies"), word.count > 4 { return String(word.dropLast(3)) + "y" }
        if word.hasSuffix("s"), !word.hasSuffix("ss"), word.count > 3 { return String(word.dropLast()) }
        return word
    }
}

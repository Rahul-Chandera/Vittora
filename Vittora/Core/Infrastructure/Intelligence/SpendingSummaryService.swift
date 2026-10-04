import Foundation
import VittoraCore
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Optional natural-language summary of a month's spending (M3.2.6).
///
/// # The hallucination guard
///
/// The scope note permits AI for summarisation and warns about hallucination
/// risk. In a finance app an invented figure is not a cosmetic error — a user
/// could act on it. So the model is never asked to compute anything:
///
/// 1. every figure is computed rules-based and handed over as a fact;
/// 2. the model is asked only to phrase those facts;
/// 3. the output is then **validated** — any number in the prose that was not
///    in the facts means the model invented it, and the whole summary is
///    discarded in favour of a deterministic sentence.
///
/// That check is the point of this type. A summary that reads well but states a
/// figure the ledger does not contain is worse than no summary.
///
/// The feature is optional throughout: unsupported device, Apple Intelligence
/// switched off, or a model failure all fall back to the deterministic text.
nonisolated struct SpendingSummaryService: Sendable {

    /// The figures, computed before the model is involved.
    nonisolated struct Facts: Sendable, Equatable {
        nonisolated let monthName: String
        nonisolated let totalSpent: Decimal
        nonisolated let totalIncome: Decimal
        nonisolated let topCategoryName: String?
        nonisolated let topCategoryAmount: Decimal?
        nonisolated let comparedWithTypical: Decimal?
        nonisolated let currencyCode: String

        nonisolated init(
            monthName: String,
            totalSpent: Decimal,
            totalIncome: Decimal,
            topCategoryName: String? = nil,
            topCategoryAmount: Decimal? = nil,
            comparedWithTypical: Decimal? = nil,
            currencyCode: String
        ) {
            self.monthName = monthName
            self.totalSpent = totalSpent
            self.totalIncome = totalIncome
            self.topCategoryName = topCategoryName
            self.topCategoryAmount = topCategoryAmount
            self.comparedWithTypical = comparedWithTypical
            self.currencyCode = currencyCode
        }

        /// Every figure the model is allowed to state.
        ///
        /// Kept as Decimals and compared numerically rather than as strings:
        /// currency formatting produces "£1,250.00" while the raw fact is 1250,
        /// and string matching rejected the app's own fallback sentence.
        nonisolated var permittedValues: [Decimal] {
            var values: [Decimal] = [totalSpent, totalIncome]
            if let topCategoryAmount { values.append(topCategoryAmount) }
            if let comparedWithTypical { values.append(abs(comparedWithTypical)) }
            return values
        }
    }

    nonisolated struct Summary: Sendable, Equatable {
        nonisolated let text: String
        /// False when the deterministic fallback produced it, so the UI can
        /// avoid claiming this was written by Apple Intelligence.
        nonisolated let isModelGenerated: Bool
    }

    /// True only when the device supports it AND the user has it enabled.
    nonisolated static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available: return true
            default: return false
            }
        }
        return false
        #else
        return false
        #endif
    }

    /// Always returns something. The model is an enhancement, never a
    /// dependency — the deterministic sentence is a complete answer on its own.
    nonisolated func summarise(_ facts: Facts) async -> Summary {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *), Self.isAvailable {
            if let text = await generate(facts), Self.isFaithful(text, to: facts) {
                return Summary(text: text, isModelGenerated: true)
            }
        }
        #endif
        return Summary(text: Self.deterministicSummary(facts), isModelGenerated: false)
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, *)
    private func generate(_ facts: Facts) async -> String? {
        let instructions = """
        You rewrite a set of already-calculated personal finance figures as two \
        short, plain sentences.

        Rules you must follow:
        - Use only the numbers given to you. Never calculate, estimate or infer \
        any figure.
        - Do not give financial advice, recommendations or opinions.
        - Do not praise or criticise the person.
        - Be factual and neutral.
        """
        let prompt = """
        Month: \(facts.monthName)
        Total spent: \(facts.totalSpent)
        Total income: \(facts.totalIncome)
        \(facts.topCategoryName.map { "Largest category: \($0) at \(facts.topCategoryAmount ?? 0)" } ?? "")
        """
        do {
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(to: prompt)
            let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        } catch {
            // Any model failure falls through to the deterministic summary.
            return nil
        }
    }
    #endif

    /// Rejects a summary containing any figure that was not supplied.
    ///
    /// Numbers are parsed and compared numerically, not matched as strings: a
    /// fact of 1250 can legitimately be written "1,250", "1250" or "£1,250.00",
    /// and an earlier string-matching version rejected the app's own fallback
    /// sentence for exactly that reason.
    ///
    /// Deliberately strict about what it lets through. Showing one figure the
    /// ledger does not contain is worse than discarding a good summary. Small
    /// integers pass because "across 12 days" is not a financial claim.
    nonisolated static func isFaithful(_ text: String, to facts: Facts) -> Bool {
        let permitted = facts.permittedValues
        let separators = CharacterSet(charactersIn: "0123456789,.").inverted

        for rawToken in text.components(separatedBy: separators) {
            let token = rawToken.trimmingCharacters(in: CharacterSet(charactersIn: ",."))
            guard !token.isEmpty, token.contains(where: \.isNumber) else { continue }
            guard let value = Decimal(string: token.replacingOccurrences(of: ",", with: "")) else { continue }

            // A bare small integer is a count or a date, not a money claim.
            if value <= 31, value == value.rounded(scale: 0) { continue }

            let matches = permitted.contains { fact in
                fact.rounded(scale: 2) == value.rounded(scale: 2)
                    || fact.rounded(scale: 0) == value.rounded(scale: 0)
            }
            if !matches { return false }
        }
        return true
    }

    /// The complete answer when the model is unavailable or untrusted. Plain,
    /// factual, and built from the same facts.
    nonisolated static func deterministicSummary(_ facts: Facts) -> String {
        let spent = facts.totalSpent.formatted(.currency(code: facts.currencyCode))
        let income = facts.totalIncome.formatted(.currency(code: facts.currencyCode))
        if let category = facts.topCategoryName,
           let amount = facts.topCategoryAmount {
            let categoryAmount = amount.formatted(.currency(code: facts.currencyCode))
            return String(localized: "In \(facts.monthName) you spent \(spent) against \(income) of income. Your largest category was \(category) at \(categoryAmount).")
        }
        return String(localized: "In \(facts.monthName) you spent \(spent) against \(income) of income.")
    }
}

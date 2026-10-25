import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Understands a typed question with Apple Intelligence's on-device model, where the
/// device has it and the user has it switched on.
///
/// The model's only job is to fill in a `MoneyQuestion`: which measure, which period,
/// and which of the user's own category or payee names. It is given no figures and its
/// output contains none, so it cannot invent a number. Names it returns are kept only if
/// they match the user's lists exactly.
enum MoneyQuestionModelInterpreter {
    static var isAvailable: Bool { SpendingSummaryService.isAvailable }

    /// Nil when the model is unavailable or fails; the caller falls back to keywords.
    static func interpret(
        _ text: String,
        categoryNames: [String],
        payeeNames: [String]
    ) async -> MoneyQuestion? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *), isAvailable {
            return await generate(text, categoryNames: categoryNames, payeeNames: payeeNames)
        }
        #endif
        return nil
    }

    /// Keeps a returned name only if it is one of the user's own, in their spelling.
    static func matched(_ name: String, in names: [String]) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return names.first { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, *)
    private static func generate(_ text: String, categoryNames: [String], payeeNames: [String]) async -> MoneyQuestion? {
        let instructions = """
        You turn a person's question about their own spending and income into a structured \
        query. You never answer the question and never write any numbers.
        Copy a category or payee name only from the lists provided, exactly as written. \
        If the question names none of them, leave that field empty.
        If no time period is mentioned, use thisMonth.
        """
        let prompt = """
        Categories: \(categoryNames.prefix(150).joined(separator: ", "))
        Payees: \(payeeNames.prefix(150).joined(separator: ", "))
        Question: \(text)
        """
        do {
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(to: prompt, generating: GeneratedMoneyQuestion.self)
            let generated = response.content
            return MoneyQuestion(
                measure: MoneyQuestion.Measure(rawValue: generated.measure.rawValue) ?? .spent,
                period: MoneyQuestion.Period(rawValue: generated.period.rawValue) ?? .thisMonth,
                categoryName: matched(generated.categoryName, in: categoryNames),
                payeeName: matched(generated.payeeName, in: payeeNames)
            )
        } catch {
            return nil
        }
    }
    #endif
}

#if canImport(FoundationModels)
@available(iOS 26.0, macOS 26.0, *)
@Generable
struct GeneratedMoneyQuestion {
    @Guide(description: "What the person wants to know about their money")
    var measure: GeneratedMeasure

    @Guide(description: "The time period the question is about")
    var period: GeneratedPeriod

    @Guide(description: "A category name copied exactly from the Categories list, or an empty string")
    var categoryName: String

    @Guide(description: "A payee or merchant name copied exactly from the Payees list, or an empty string")
    var payeeName: String
}

@available(iOS 26.0, macOS 26.0, *)
@Generable
enum GeneratedMeasure: String {
    case spent, earned, topCategories, biggestExpense, transactionCount
}

@available(iOS 26.0, macOS 26.0, *)
@Generable
enum GeneratedPeriod: String {
    case today, thisWeek, thisMonth, lastMonth, last30Days, thisYear, lastYear
}
#endif

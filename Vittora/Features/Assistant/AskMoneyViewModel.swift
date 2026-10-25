import Foundation
import Observation
import VittoraCore

@Observable
@MainActor
final class AskMoneyViewModel {
    /// Ready-made questions. They skip interpretation entirely, so they work everywhere.
    struct Suggestion: Identifiable {
        let id: String
        let title: String
        let question: MoneyQuestion

        static var all: [Suggestion] {
            [
                Suggestion(id: "spent", title: String(localized: "How much did I spend this month?"),
                           question: MoneyQuestion(measure: .spent, period: .thisMonth)),
                Suggestion(id: "top", title: String(localized: "What were my top categories last month?"),
                           question: MoneyQuestion(measure: .topCategories, period: .lastMonth)),
                Suggestion(id: "biggest", title: String(localized: "What was my biggest expense this month?"),
                           question: MoneyQuestion(measure: .biggestExpense, period: .thisMonth)),
                Suggestion(id: "earned", title: String(localized: "How much did I earn this year?"),
                           question: MoneyQuestion(measure: .earned, period: .thisYear)),
            ]
        }
    }

    private let engine: MoneyAnswerEngine
    private let categoryRepository: any CategoryRepository
    private let payeeRepository: any PayeeRepository

    var questionText = ""
    private(set) var askedQuestion: String?
    private(set) var answer: MoneyAnswer?
    /// True when Apple Intelligence interpreted the question, so the screen can say so.
    private(set) var understoodByModel = false
    private(set) var isAnswering = false
    private(set) var payeeNames: [UUID: String] = [:]
    var error: String?

    init(
        engine: MoneyAnswerEngine,
        categoryRepository: any CategoryRepository,
        payeeRepository: any PayeeRepository
    ) {
        self.engine = engine
        self.categoryRepository = categoryRepository
        self.payeeRepository = payeeRepository
    }

    var canAsk: Bool {
        !isAnswering && !questionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func askTypedQuestion(currencyCode: String) async {
        let text = questionText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        await run(asked: text, currencyCode: currencyCode) { categories, payees in
            if let fromModel = await MoneyQuestionModelInterpreter.interpret(text, categoryNames: categories, payeeNames: payees) {
                return (fromModel, true)
            }
            let fromKeywords = MoneyQuestionKeywordInterpreter.interpret(text, categoryNames: categories, payeeNames: payees)
            return (fromKeywords, false)
        }
    }

    func ask(_ suggestion: Suggestion, currencyCode: String) async {
        questionText = ""
        await run(asked: suggestion.title, currencyCode: currencyCode) { _, _ in (suggestion.question, false) }
    }

    private func run(
        asked: String,
        currencyCode: String,
        interpret: ([String], [String]) async -> (MoneyQuestion, Bool)
    ) async {
        isAnswering = true
        error = nil
        defer { isAnswering = false }
        do {
            let categories = try await categoryRepository.fetchAll()
            let payees = try await payeeRepository.fetchAll()
            payeeNames = Dictionary(payees.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
            let (question, usedModel) = await interpret(categories.map(\.name), payees.map(\.name))
            answer = try await engine.answer(question, currencyCode: currencyCode)
            askedQuestion = asked
            understoodByModel = usedModel
        } catch {
            self.error = String(localized: "Vittora couldn't answer that right now. Try again.")
        }
    }
}

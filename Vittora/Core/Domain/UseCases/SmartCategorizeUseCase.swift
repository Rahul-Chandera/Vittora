import Foundation
import NaturalLanguage
import VittoraCore

struct SmartCategorizeRequest: Sendable {
    var payeeID: UUID?
    var payeeName: String?
    var note: String?
    var merchantText: String?
    var rawOCRText: String?
    var amount: Decimal
}

struct SmartCategorizeUseCase: Sendable {
    let transactionRepository: any TransactionRepository
    let ruleStore: any CategorizationRuleStoring
    let categoryRepository: any CategoryRepository

    nonisolated init(
        transactionRepository: any TransactionRepository,
        ruleStore: any CategorizationRuleStoring,
        categoryRepository: any CategoryRepository
    ) {
        self.transactionRepository = transactionRepository
        self.ruleStore = ruleStore
        self.categoryRepository = categoryRepository
    }

    /// Rules, then payee history, then the on-device classifier (M3.2.1).
    ///
    /// The classifier is LAST deliberately. A rule is the user stating what they
    /// want, and payee history is what they have actually done before — both are
    /// stronger evidence than a similarity score, and neither should be
    /// overridden by one. The classifier earns its place on the cases the other
    /// two cannot answer: a manual entry or a scanned receipt with no payee.
    func execute(_ request: SmartCategorizeRequest) async throws -> UUID? {
        if let categoryID = try await matchRule(for: request) {
            return categoryID
        }
        if let categoryID = try await categoryFromPayeeHistory(payeeID: request.payeeID) {
            return categoryID
        }
        return try await categoryFromClassifier(for: request)
    }

    /// Nil on every failure path — no embedding for the language, too little
    /// history, or a match too weak to offer. A wrong suggestion costs the user
    /// more than no suggestion, because they have to notice it and undo it.
    private func categoryFromClassifier(for request: SmartCategorizeRequest) async throws -> UUID? {
        let text = Self.haystack(
            payeeName: request.payeeName,
            note: request.note,
            merchantText: request.merchantText,
            rawOCRText: request.rawOCRText
        )
        guard !text.isEmpty,
              let embedding = SmartCategoryClassifier.embedding()
        else { return nil }

        let transactions = try await transactionRepository.fetchAll(filter: nil)
        let examples: [SmartCategoryClassifier.Example] = transactions.compactMap { transaction in
            guard let categoryID = transaction.categoryID else { return nil }
            let descriptor = Self.haystack(
                payeeName: transaction.note,
                note: nil,
                merchantText: nil,
                rawOCRText: nil
            )
            guard !descriptor.isEmpty else { return nil }
            return SmartCategoryClassifier.Example(text: descriptor, categoryID: categoryID)
        }
        guard !examples.isEmpty else { return nil }

        let classifier = SmartCategoryClassifier()
        let model = classifier.fit(examples: examples, embedding: embedding)
        guard let prediction = classifier.predict(text: text, model: model, embedding: embedding)
        else { return nil }

        // A category deleted since it was learned must not be suggested.
        guard try await categoryRepository.fetchByID(prediction.categoryID) != nil else { return nil }
        return prediction.categoryID
    }

    func execute(payeeID: UUID?, amount: Decimal) async throws -> UUID? {
        try await execute(SmartCategorizeRequest(payeeID: payeeID, amount: amount))
    }

    private func matchRule(for request: SmartCategorizeRequest) async throws -> UUID? {
        let haystack = Self.haystack(
            payeeName: request.payeeName,
            note: request.note,
            merchantText: request.merchantText,
            rawOCRText: request.rawOCRText
        )
        guard !haystack.isEmpty else { return nil }

        let rules = try ruleStore.fetchAll()
        let sortedRules = rules
            .filter(\.isEnabled)
            .filter { !$0.normalizedKeyword.isEmpty }
            .sorted { $0.normalizedKeyword.count > $1.normalizedKeyword.count }

        for rule in sortedRules {
            if haystack.contains(rule.normalizedKeyword),
               try await categoryRepository.fetchByID(rule.categoryID) != nil {
                return rule.categoryID
            }
        }
        return nil
    }

    private func categoryFromPayeeHistory(payeeID: UUID?) async throws -> UUID? {
        guard let payeeID else { return nil }

        let filter = TransactionFilter(payeeIDs: [payeeID])
        let transactions = try await transactionRepository.fetchAll(filter: filter)
        let categorizedTransactions = transactions.filter { $0.categoryID != nil }
        guard !categorizedTransactions.isEmpty else { return nil }

        let categoryCounts = Dictionary(grouping: categorizedTransactions, by: { $0.categoryID })
            .mapValues { $0.count }

        return categoryCounts.max(by: { $0.value < $1.value })?.key ?? nil
    }

    nonisolated static func haystack(
        payeeName: String?,
        note: String?,
        merchantText: String?,
        rawOCRText: String?
    ) -> String {
        [payeeName, note, merchantText, rawOCRText]
            .compactMap { value in
                let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return trimmed.isEmpty ? nil : trimmed
            }
            .joined(separator: " ")
            .lowercased()
    }
}

import Foundation
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

    func execute(_ request: SmartCategorizeRequest) async throws -> UUID? {
        if let categoryID = try await matchRule(for: request) {
            return categoryID
        }
        return try await categoryFromPayeeHistory(payeeID: request.payeeID)
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

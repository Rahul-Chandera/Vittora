import Foundation
import VittoraCore

struct CategorizationRuleRowModel: Identifiable, Sendable {
    let id: UUID
    let keyword: String
    let categoryName: String
    let categoryIcon: String
    let categoryColorHex: String
    let isEnabled: Bool
    let categoryID: UUID
}

@Observable @MainActor final class CategorizationRulesViewModel {
    var rules: [CategorizationRuleRowModel] = []
    var categories: [CategoryEntity] = []
    var isLoading = false
    var error: String?

    private let manageRulesUseCase: ManageCategorizationRulesUseCase
    private let fetchCategoriesUseCase: FetchCategoriesUseCase

    init(
        manageRulesUseCase: ManageCategorizationRulesUseCase,
        fetchCategoriesUseCase: FetchCategoriesUseCase
    ) {
        self.manageRulesUseCase = manageRulesUseCase
        self.fetchCategoriesUseCase = fetchCategoriesUseCase
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        error = nil

        do {
            let fetchedCategories = try await fetchCategoriesUseCase.execute()
            categories = fetchedCategories
            let categoryLookup = Dictionary(uniqueKeysWithValues: fetchedCategories.map { ($0.id, $0) })
            let storedRules = try await manageRulesUseCase.fetchAll()
            rules = storedRules.map { rule in
                let category = categoryLookup[rule.categoryID]
                return CategorizationRuleRowModel(
                    id: rule.id,
                    keyword: rule.keyword,
                    categoryName: category?.displayName ?? String(localized: "Unknown category"),
                    categoryIcon: category?.icon ?? "tag.fill",
                    categoryColorHex: category?.colorHex ?? "#888888",
                    isEnabled: rule.isEnabled,
                    categoryID: rule.categoryID
                )
            }
            .sorted { $0.keyword.localizedCaseInsensitiveCompare($1.keyword) == .orderedAscending }
        } catch {
            self.error = error.userFacingMessage(
                fallback: String(localized: "We couldn't load categorization rules right now.")
            )
        }
    }

    func deleteRule(id: UUID) async {
        error = nil
        do {
            try await manageRulesUseCase.delete(id: id)
            rules.removeAll { $0.id == id }
        } catch {
            self.error = error.userFacingMessage(
                fallback: String(localized: "We couldn't delete this rule right now.")
            )
        }
    }

    func toggleRule(id: UUID, isEnabled: Bool) async {
        error = nil
        do {
            let storedRules = try await manageRulesUseCase.fetchAll()
            guard var rule = storedRules.first(where: { $0.id == id }) else { return }
            rule.isEnabled = isEnabled
            try await manageRulesUseCase.save(rule)
            if let index = rules.firstIndex(where: { $0.id == id }) {
                let existing = rules[index]
                rules[index] = CategorizationRuleRowModel(
                    id: existing.id,
                    keyword: existing.keyword,
                    categoryName: existing.categoryName,
                    categoryIcon: existing.categoryIcon,
                    categoryColorHex: existing.categoryColorHex,
                    isEnabled: isEnabled,
                    categoryID: existing.categoryID
                )
            }
        } catch {
            self.error = error.userFacingMessage(
                fallback: String(localized: "We couldn't update this rule right now.")
            )
        }
    }
}

@Observable @MainActor final class CategorizationRuleFormViewModel {
    var keyword: String = ""
    var selectedCategoryID: UUID?
    var isEnabled: Bool = true
    var isSaving = false
    var error: String?

    private let manageRulesUseCase: ManageCategorizationRulesUseCase
    private let editingRuleID: UUID?

    init(
        manageRulesUseCase: ManageCategorizationRulesUseCase,
        existingRule: CategorizationRule? = nil
    ) {
        self.manageRulesUseCase = manageRulesUseCase
        self.editingRuleID = existingRule?.id
        if let existingRule {
            keyword = existingRule.keyword
            selectedCategoryID = existingRule.categoryID
            isEnabled = existingRule.isEnabled
        }
    }

    var canSave: Bool {
        !keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedCategoryID != nil
    }

    func save() async -> Bool {
        guard canSave, let selectedCategoryID else { return false }

        isSaving = true
        defer { isSaving = false }
        error = nil

        let rule = CategorizationRule(
            id: editingRuleID ?? UUID(),
            keyword: keyword,
            categoryID: selectedCategoryID,
            isEnabled: isEnabled
        )

        do {
            try await manageRulesUseCase.save(rule)
            return true
        } catch {
            self.error = error.userFacingMessage(
                fallback: String(localized: "We couldn't save this rule right now.")
            )
            return false
        }
    }
}

import Foundation

struct FetchTaxCategoriesUseCase: Sendable {
    private let repository: any CategoryRepository

    init(repository: any CategoryRepository) {
        self.repository = repository
    }

    func execute(country: TaxCountry) async throws -> [CategoryEntity] {
        let categories = try await repository.fetchByType(.expense)
        return categories
            .filter { isTaxRelevant($0, country: country) }
            .sorted { lhs, rhs in
                if lhs.sortOrder == rhs.sortOrder {
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }
                return lhs.sortOrder < rhs.sortOrder
            }
    }

    func isTaxRelevant(_ category: CategoryEntity, country: TaxCountry) -> Bool {
        let normalizedName = normalizedTokens(in: category.name)
        let normalizedIcon = category.icon.lowercased()
        let matcher = keywordMatcher(for: country)

        if matcher.keywords.contains(where: normalizedName.contains) {
            return true
        }

        return matcher.iconKeywords.contains(where: normalizedIcon.contains)
    }

    private func normalizedTokens(in value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
    }

    private func keywordMatcher(for country: TaxCountry) -> (keywords: [String], iconKeywords: [String]) {
        let sharedKeywords = [
            "charity", "donation", "education", "health", "medical", "insurance",
            "mortgage", "retirement", "school", "student loan", "tax", "tuition",
        ]
        let sharedIcons = ["book", "cross", "graduationcap", "heart", "house", "shield"]

        switch country {
        case .india:
            return (
                keywords: sharedKeywords + [
                    "80c", "80d", "elss", "epf", "health insurance", "home loan",
                    "hra", "interest", "nps", "ppf", "provident fund", "ulip",
                ],
                iconKeywords: sharedIcons + ["leaf", "hands.sparkles"]
            )

        case .unitedStates:
            return (
                keywords: sharedKeywords + [
                    "401k", "529", "fsa", "hsa", "ira", "property tax",
                    "roth", "state tax",
                ],
                iconKeywords: sharedIcons + ["stethoscope"]
            )
        }
    }
}

import Foundation

public enum CategoryType: String, Sendable, Hashable, CaseIterable, Codable {
    case expense, income
}

public enum SpendingBucket: String, Sendable, Hashable, CaseIterable, Codable {
    case needs
    case wants
    case savings

    public var displayName: String {
        switch self {
        case .needs: String(localized: "Needs")
        case .wants: String(localized: "Wants")
        case .savings: String(localized: "Savings")
        }
    }

    public nonisolated static func defaultBucket(
        categoryName: String,
        type: CategoryType
    ) -> SpendingBucket {
        guard type == .expense else { return .wants }
        let needs = [
            "Groceries", "Transport", "Health", "Education", "Utilities", "Rent",
            "EMI", "Insurance", "Personal Care", "Phone", "Internet", "Clothing", "Pets",
        ]
        return needs.contains(categoryName) ? .needs : .wants
    }
}

public struct CategoryEntity: Identifiable, Hashable, Equatable, Sendable {
    public nonisolated let id: UUID
    public nonisolated var name: String
    public nonisolated var icon: String
    public nonisolated var colorHex: String
    public nonisolated var type: CategoryType
    public nonisolated var isDefault: Bool
    public nonisolated var sortOrder: Int
    public nonisolated var parentID: UUID?
    public nonisolated var spendingBucket: SpendingBucket?
    public nonisolated var createdAt: Date
    public nonisolated var updatedAt: Date

    public nonisolated var displayName: String {
        displayName(locale: .current)
    }

    public nonisolated func displayName(locale: Locale, bundle: Bundle = .main) -> String {
        guard isDefault else { return name }
        let localizedBundle = locale.language.languageCode
            .flatMap { bundle.url(forResource: $0.identifier, withExtension: "lproj") }
            .flatMap(Bundle.init(url:))
            ?? bundle

        return switch name {
        case "Groceries": String(localized: "Groceries", bundle: localizedBundle)
        case "Dining": String(localized: "Dining", bundle: localizedBundle)
        case "Transport": String(localized: "Transport", bundle: localizedBundle)
        case "Entertainment": String(localized: "Entertainment", bundle: localizedBundle)
        case "Shopping": String(localized: "Shopping", bundle: localizedBundle)
        case "Health": String(localized: "Health", bundle: localizedBundle)
        case "Education": String(localized: "Education", bundle: localizedBundle)
        case "Utilities": String(localized: "Utilities", bundle: localizedBundle)
        case "Rent": String(localized: "Rent", bundle: localizedBundle)
        case "EMI": String(localized: "EMI", bundle: localizedBundle)
        case "Insurance": String(localized: "Insurance", bundle: localizedBundle)
        case "Personal Care": String(localized: "Personal Care", bundle: localizedBundle)
        case "Gifts": String(localized: "Gifts", bundle: localizedBundle)
        case "Travel": String(localized: "Travel", bundle: localizedBundle)
        case "Subscriptions": String(localized: "Subscriptions", bundle: localizedBundle)
        case "Phone": String(localized: "Phone", bundle: localizedBundle)
        case "Internet": String(localized: "Internet", bundle: localizedBundle)
        case "Clothing": String(localized: "Clothing", bundle: localizedBundle)
        case "Pets": String(localized: "Pets", bundle: localizedBundle)
        case "Charity": String(localized: "Charity", bundle: localizedBundle)
        case "Other": String(localized: "Other", bundle: localizedBundle)
        case "Salary": String(localized: "Salary", bundle: localizedBundle)
        case "Freelance": String(localized: "Freelance", bundle: localizedBundle)
        case "Investments": String(localized: "Investments", bundle: localizedBundle)
        case "Gifts Received": String(localized: "Gifts Received", bundle: localizedBundle)
        case "Other Income": String(localized: "Other Income", bundle: localizedBundle)
        default: name
        }
    }

    public nonisolated init(
        id: UUID = UUID(),
        name: String,
        icon: String,
        colorHex: String = "#007AFF",
        type: CategoryType = .expense,
        isDefault: Bool = false,
        sortOrder: Int = 0,
        parentID: UUID? = nil,
        spendingBucket: SpendingBucket? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.type = type
        self.isDefault = isDefault
        self.sortOrder = sortOrder
        self.parentID = parentID
        self.spendingBucket = spendingBucket
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: - Equatable & Hashable (identity-based)

    // Value equality, not identity. An id-only `==` makes SwiftUI treat a
    // record whose fields changed as unchanged, so any row whose only input is
    // this entity never re-renders — it keeps the old figures until the app is
    // relaunched. That shipped as a budget bug; see BudgetEntity for the full
    // account. `createdAt`/`updatedAt` are audit metadata, not displayed
    // content, so they stay out of the comparison. Dedup by identity should
    // key on `id` explicitly rather than lean on `==`.
    public static func == (lhs: CategoryEntity, rhs: CategoryEntity) -> Bool {
        lhs.id == rhs.id
            && lhs.name == rhs.name
            && lhs.icon == rhs.icon
            && lhs.colorHex == rhs.colorHex
            && lhs.type == rhs.type
            && lhs.isDefault == rhs.isDefault
            && lhs.sortOrder == rhs.sortOrder
            && lhs.parentID == rhs.parentID
            && lhs.spendingBucket == rhs.spendingBucket
    }
    // Hash stays id-only: legal (equal values share a hash) and keeps
    // Set/Dictionary bucketing stable as mutable fields change.
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

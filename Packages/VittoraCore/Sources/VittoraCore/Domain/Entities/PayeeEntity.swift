import Foundation

public enum PayeeType: String, Sendable, Hashable, CaseIterable, Codable {
    case person, business
}

public struct PayeeEntity: Identifiable, Hashable, Equatable, Sendable {
    public nonisolated let id: UUID
    public nonisolated var name: String
    public nonisolated var type: PayeeType
    public nonisolated var phone: String?
    public nonisolated var email: String?
    public nonisolated var notes: String?
    public nonisolated var createdAt: Date
    public nonisolated var updatedAt: Date

    public nonisolated init(
        id: UUID = UUID(),
        name: String,
        type: PayeeType = .business,
        phone: String? = nil,
        email: String? = nil,
        notes: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.phone = phone
        self.email = email
        self.notes = notes
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
    public static func == (lhs: PayeeEntity, rhs: PayeeEntity) -> Bool {
        lhs.id == rhs.id
            && lhs.name == rhs.name
            && lhs.type == rhs.type
            && lhs.phone == rhs.phone
            && lhs.email == rhs.email
            && lhs.notes == rhs.notes
    }
    // Hash stays id-only: legal (equal values share a hash) and keeps
    // Set/Dictionary bucketing stable as mutable fields change.
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

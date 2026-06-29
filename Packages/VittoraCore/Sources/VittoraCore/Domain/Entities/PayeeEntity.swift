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

    public static func == (lhs: PayeeEntity, rhs: PayeeEntity) -> Bool { lhs.id == rhs.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

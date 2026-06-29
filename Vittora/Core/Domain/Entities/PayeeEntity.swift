import Foundation

enum PayeeType: String, Sendable, Hashable, CaseIterable, Codable {
    case person, business
}

struct PayeeEntity: Identifiable, Hashable, Equatable, Sendable {
    nonisolated let id: UUID
    nonisolated var name: String
    nonisolated var type: PayeeType
    nonisolated var phone: String?
    nonisolated var email: String?
    nonisolated var notes: String?
    nonisolated var createdAt: Date
    nonisolated var updatedAt: Date

    nonisolated init(
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

    static func == (lhs: PayeeEntity, rhs: PayeeEntity) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

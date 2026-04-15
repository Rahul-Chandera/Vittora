import Foundation

enum PayeeType: String, Sendable, Hashable, CaseIterable, Codable {
    case person, business
}

struct PayeeEntity: Identifiable, Hashable, Equatable, Sendable {
    let id: UUID
    var name: String
    var type: PayeeType
    var phone: String?
    var email: String?
    var notes: String?
    var createdAt: Date
    var updatedAt: Date

    init(
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

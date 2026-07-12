import Foundation
import VittoraCore

struct TransactionFilterSnapshot: Codable, Sendable, Equatable {
    var startDate: Date?
    var endDate: Date?
    var selectedTypeRaws: [String]
    var amountMin: String
    var amountMax: String
    var datePresetRaw: String
}

struct SavedTransactionFilterPreset: Codable, Sendable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var snapshot: TransactionFilterSnapshot

    init(id: UUID = UUID(), name: String, snapshot: TransactionFilterSnapshot) {
        self.id = id
        self.name = name
        self.snapshot = snapshot
    }
}

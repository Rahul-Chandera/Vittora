import Foundation
import VittoraCore

protocol SavedTransactionFilterStoring: Sendable {
    func fetchAll() throws -> [SavedTransactionFilterPreset]
    func save(_ preset: SavedTransactionFilterPreset) throws
    func delete(id: UUID) throws
}

enum SavedTransactionFilterStore {
    nonisolated static func clearAll(userDefaults: UserDefaults = .standard) {
        userDefaults.removeObject(forKey: AppUserDefaults.StandardKey.savedTransactionFilters)
    }
}

final class UserDefaultsSavedTransactionFilterStore: SavedTransactionFilterStoring, @unchecked Sendable {
    nonisolated(unsafe) private let userDefaults: UserDefaults
    nonisolated private let storageKey = AppUserDefaults.StandardKey.savedTransactionFilters
    nonisolated private let lock = NSLock()

    nonisolated init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    nonisolated func fetchAll() throws -> [SavedTransactionFilterPreset] {
        lock.lock()
        defer { lock.unlock() }
        return try decodePresetsLocked()
    }

    nonisolated func save(_ preset: SavedTransactionFilterPreset) throws {
        lock.lock()
        defer { lock.unlock() }
        var presets = try decodePresetsLocked()
        if let index = presets.firstIndex(where: { $0.id == preset.id }) {
            presets[index] = preset
        } else {
            presets.append(preset)
        }
        try encodePresetsLocked(presets)
    }

    nonisolated func delete(id: UUID) throws {
        lock.lock()
        defer { lock.unlock() }
        var presets = try decodePresetsLocked()
        presets.removeAll { $0.id == id }
        try encodePresetsLocked(presets)
    }

    nonisolated private func decodePresetsLocked() throws -> [SavedTransactionFilterPreset] {
        guard let data = userDefaults.data(forKey: storageKey) else {
            return []
        }
        return try JSONDecoder().decode([SavedTransactionFilterPreset].self, from: data)
    }

    nonisolated private func encodePresetsLocked(_ presets: [SavedTransactionFilterPreset]) throws {
        let data = try JSONEncoder().encode(presets)
        userDefaults.set(data, forKey: storageKey)
    }
}

struct ManageSavedTransactionFiltersUseCase: Sendable {
    let store: any SavedTransactionFilterStoring

    func fetchAll() throws -> [SavedTransactionFilterPreset] {
        try store.fetchAll().sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func save(name: String, snapshot: TransactionFilterSnapshot) throws -> SavedTransactionFilterPreset {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw VittoraError.validationFailed(String(localized: "Filter name is required."))
        }
        let preset = SavedTransactionFilterPreset(name: trimmed, snapshot: snapshot)
        try store.save(preset)
        return preset
    }

    func delete(id: UUID) throws {
        try store.delete(id: id)
    }
}

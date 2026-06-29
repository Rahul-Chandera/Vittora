import Foundation

public enum KeychainItemAccess: Sendable, Equatable {
    case standard
    case biometricBound
}

@MainActor
public protocol KeychainServiceProtocol: Sendable {
    func save(_ data: Data, forKey key: String, access: KeychainItemAccess) async throws
    func load(forKey key: String, access: KeychainItemAccess) async throws -> Data?
    func delete(forKey key: String) async throws
    func exists(forKey key: String) async throws -> Bool
}

public extension KeychainServiceProtocol {
    func save(_ data: Data, forKey key: String) async throws {
        try await save(data, forKey: key, access: .standard)
    }

    func load(forKey key: String) async throws -> Data? {
        try await load(forKey: key, access: .standard)
    }
}

@MainActor
public protocol EncryptionServiceProtocol: Sendable {
    func encrypt(_ data: Data) async throws -> Data
    func decrypt(_ encryptedData: Data) async throws -> Data
    func generateKey() async throws
}

public enum SecurityAuditEventKind: String, Codable, Sendable {
    case appLocked
    case appUnlocked
    case exportCreated
    case syncConflictAutoResolved
    case syncIntegrityViolation
    case encryptionKeyRotated
}

public struct SecurityAuditEvent: Sendable {
    public let kind: SecurityAuditEventKind
    public let detail: String

    public init(kind: SecurityAuditEventKind, detail: String) {
        self.kind = kind
        self.detail = detail
    }
}

public protocol SecurityAuditLogging: Sendable {
    func record(_ event: SecurityAuditEvent) async
}

public enum BiometricType: Sendable {
    case faceID, touchID, opticID, none
}

@MainActor
public protocol BiometricServiceProtocol: Sendable {
    func canUseBiometrics() -> Bool
    func authenticate(reason: String, allowPasscodeFallback: Bool) async throws -> Bool
    func authenticateWithPasscode(reason: String) async throws -> Bool
    var biometricType: BiometricType { get }
}

@MainActor
public protocol AppLockServiceProtocol: Sendable {
    var isLocked: Bool { get }
    var lastBackgroundedAt: Date? { get }
    var cooldownExpiresAt: Date? { get }
    func recordBackgrounded(at date: Date)
    func lock() async
    func unlock(allowPasscodeFallback: Bool) async throws -> Bool
    func unlockWithPasscode() async throws -> Bool
}

public protocol AppLockCooldownStoring: Sendable {
    func load(now: Date) -> AppLockCooldownState
    func save(_ state: AppLockCooldownState)
    func clear()
}

public extension AppLockCooldownStoring {
    func load() -> AppLockCooldownState {
        load(now: .now)
    }
}

public struct IntegrityViolation: Sendable {
    public let entityType: String
    public let entityID: UUID?
    public let description: String

    public init(entityType: String, entityID: UUID?, description: String) {
        self.entityType = entityType
        self.entityID = entityID
        self.description = description
    }
}

public protocol SyncIntegrityValidating: Sendable {
    func validateAmountBearingEntities() async -> [IntegrityViolation]
}

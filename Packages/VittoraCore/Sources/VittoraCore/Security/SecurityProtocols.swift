import Foundation

public enum KeychainItemAccess: Sendable, Equatable {
    case standard
    case biometricBound
}

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

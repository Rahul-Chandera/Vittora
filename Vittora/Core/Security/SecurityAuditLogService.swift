import Foundation

enum SecurityAuditEventKind: String, Codable, Sendable {
    case appLocked
    case appUnlocked
    case exportCreated
    case syncConflictAutoResolved
    case syncIntegrityViolation
    case encryptionKeyRotated
}

struct SecurityAuditEvent: Sendable {
    let kind: SecurityAuditEventKind
    let detail: String
}

protocol SecurityAuditLogging: Sendable {
    func record(_ event: SecurityAuditEvent) async
}

struct SecurityAuditLogEntry: Codable, Sendable, Identifiable {
    let id: UUID
    let recordedAt: Date
    let kind: SecurityAuditEventKind
    let detail: String
}

/// Append-only encrypted audit trail (SEC-18). Stored under Application Support with complete file protection.
@MainActor
final class SecurityAuditLogService: SecurityAuditLogging, Sendable {
    private let encryptionService: any EncryptionServiceProtocol
    private let fileURL: URL
    private static let maxEntriesToRead = 200

    init(encryptionService: any EncryptionServiceProtocol) {
        self.encryptionService = encryptionService
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("Security", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.complete]
        )
        self.fileURL = dir.appendingPathComponent("audit.log.enc")
        try? FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.complete],
            ofItemAtPath: dir.path
        )
    }

    func record(_ event: SecurityAuditEvent) async {
        let line = SecurityAuditLogEntry(
            id: UUID(),
            recordedAt: Date.now,
            kind: event.kind,
            detail: String(event.detail.prefix(2_000))
        )
        do {
            let payload = try JSONEncoder().encode(line)
            let sealed = try await encryptionService.encrypt(payload)
            let encoded = sealed.base64EncodedString() + "\n"
            guard let data = encoded.data(using: .utf8) else { return }
            if !FileManager.default.fileExists(atPath: fileURL.path) {
                try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
            } else {
                let handle = try FileHandle(forWritingTo: fileURL)
                defer { try? handle.close() }
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
            }
            try? FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.complete],
                ofItemAtPath: fileURL.path
            )
        } catch {
            // Avoid throwing from audit path; OSLog only.
            PerformanceLogger.Security.auditWriteFailed(error.localizedDescription)
        }
    }

    /// Decrypted recent entries, newest last.
    func recentEntries(limit: Int = 50) async -> [SecurityAuditLogEntry] {
        let cap = min(max(limit, 1), Self.maxEntriesToRead)
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let raw = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return []
        }
        let lines = raw.split(separator: "\n", omittingEmptySubsequences: true).suffix(cap)
        var result: [SecurityAuditLogEntry] = []
        for line in lines {
            guard let data = Data(base64Encoded: String(line)) else { continue }
            do {
                let decrypted = try await encryptionService.decrypt(data)
                if let entry = try? JSONDecoder().decode(SecurityAuditLogEntry.self, from: decrypted) {
                    result.append(entry)
                }
            } catch {
                continue
            }
        }
        return result
    }
}

import Foundation
import SwiftData

enum DocumentMapper {
    nonisolated static func toEntity(_ model: SDDocument) -> DocumentEntity {
        DocumentEntity(
            id: model.id,
            fileName: model.fileName,
            mimeType: model.mimeType,
            thumbnailData: nil,
            transactionID: model.transactionID,
            createdAt: model.createdAt,
            updatedAt: model.updatedAt
        )
    }

    nonisolated static func updateModel(_ model: SDDocument, from entity: DocumentEntity) {
        model.fileName = entity.fileName
        model.mimeType = entity.mimeType
        model.transactionID = entity.transactionID
        model.updatedAt = .now
    }
}

@MainActor
final class EncryptedDocumentStorageService: DocumentStorageServiceProtocol, Sendable {
    private enum AssetKind {
        case document
        case thumbnail

        var fileSuffix: String {
            switch self {
            case .document:
                "document.enc"
            case .thumbnail:
                "thumbnail.enc"
            }
        }
    }

    private let encryptionService: any EncryptionServiceProtocol
    private let fileManager: FileManager
    private let secureBaseDirectoryURL: URL

    init(
        encryptionService: any EncryptionServiceProtocol,
        fileManager: FileManager = .default,
        secureBaseDirectoryURL: URL? = nil
    ) {
        self.encryptionService = encryptionService
        self.fileManager = fileManager
        self.secureBaseDirectoryURL = secureBaseDirectoryURL
            ?? Self.defaultSecureBaseDirectoryURL(using: fileManager)
    }

    func saveDocument(_ data: Data, for entity: DocumentEntity) async throws {
        try ensureSecureDirectoryExists()
        let encryptedData = try await encryptionService.encrypt(data)
        try writeEncryptedData(encryptedData, to: secureURL(for: entity.id, kind: .document))
        try removeItemIfPresent(at: legacyDocumentURL(for: entity.fileName))
    }

    func loadDocument(for entity: DocumentEntity) async throws -> Data {
        let encryptedURL = secureURL(for: entity.id, kind: .document)
        if fileManager.fileExists(atPath: encryptedURL.path) {
            return try await decryptContents(at: encryptedURL)
        }

        guard let legacyURL = legacyDocumentURL(for: entity.fileName),
              fileManager.fileExists(atPath: legacyURL.path) else {
            throw DocumentError.fileNotFound
        }

        let legacyData = try Data(contentsOf: legacyURL)
        try await saveDocument(legacyData, for: entity)
        return legacyData
    }

    func deleteDocument(for entity: DocumentEntity) async throws {
        try removeItemIfPresent(at: secureURL(for: entity.id, kind: .document))
        try removeItemIfPresent(at: legacyDocumentURL(for: entity.fileName))
    }

    func saveThumbnail(_ data: Data, for documentID: UUID) async throws {
        try ensureSecureDirectoryExists()
        let encryptedData = try await encryptionService.encrypt(data)
        try writeEncryptedData(encryptedData, to: secureURL(for: documentID, kind: .thumbnail))
        try removeItemIfPresent(at: legacyThumbnailURL(for: documentID))
    }

    func loadThumbnail(for documentID: UUID) async throws -> Data? {
        let encryptedURL = secureURL(for: documentID, kind: .thumbnail)
        if fileManager.fileExists(atPath: encryptedURL.path) {
            return try await decryptContents(at: encryptedURL)
        }

        guard let legacyURL = legacyThumbnailURL(for: documentID),
              fileManager.fileExists(atPath: legacyURL.path) else {
            return nil
        }

        let legacyData = try Data(contentsOf: legacyURL)
        try await saveThumbnail(legacyData, for: documentID)
        return legacyData
    }

    func deleteThumbnail(for documentID: UUID) async throws {
        try removeItemIfPresent(at: secureURL(for: documentID, kind: .thumbnail))
        try removeItemIfPresent(at: legacyThumbnailURL(for: documentID))
    }

    private static func defaultSecureBaseDirectoryURL(using fileManager: FileManager) -> URL {
        let baseDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return baseDirectory.appendingPathComponent("SecureDocuments", isDirectory: true)
    }

    private func secureURL(for documentID: UUID, kind: AssetKind) -> URL {
        secureBaseDirectoryURL.appendingPathComponent(
            "\(documentID.uuidString).\(kind.fileSuffix)"
        )
    }

    private func legacyDocumentURL(for fileName: String) -> URL? {
        fileManager
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent(fileName)
    }

    private func legacyThumbnailURL(for documentID: UUID) -> URL? {
        fileManager
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("\(documentID.uuidString)_thumb.jpg")
    }

    private func ensureSecureDirectoryExists() throws {
        if !fileManager.fileExists(atPath: secureBaseDirectoryURL.path) {
            try fileManager.createDirectory(
                at: secureBaseDirectoryURL,
                withIntermediateDirectories: true
            )
        }
    }

    private func decryptContents(at url: URL) async throws -> Data {
        let encryptedData = try Data(contentsOf: url)
        return try await encryptionService.decrypt(encryptedData)
    }

    private func writeEncryptedData(_ data: Data, to url: URL) throws {
        #if os(iOS)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        try fileManager.setAttributes(
            [.protectionKey: FileProtectionType.complete],
            ofItemAtPath: url.path
        )
        #else
        try data.write(to: url, options: [.atomic])
        #endif
    }

    private func removeItemIfPresent(at url: URL?) throws {
        guard let url else { return }

        do {
            try fileManager.removeItem(at: url)
        } catch CocoaError.fileNoSuchFile {
            return
        }
    }
}

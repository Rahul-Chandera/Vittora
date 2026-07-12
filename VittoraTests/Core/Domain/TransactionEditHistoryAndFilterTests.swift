import Foundation
import Testing
import CoreGraphics
import VittoraCore
@testable import Vittora

@Suite("Transaction Edit History")
@MainActor
struct TransactionEditHistoryTests {
    @Test("diff captures changed fields only")
    func diffCapturesChanges() {
        let before = TransactionEntity(
            id: UUID(),
            amount: 100,
            date: Date(timeIntervalSince1970: 1_000),
            note: "Coffee",
            type: .expense,
            paymentMethod: .cash,
            categoryID: UUID(),
            accountID: UUID()
        )
        var after = before
        after.amount = 120
        after.note = "Coffee shop"

        let changes = TransactionEditDiff.changes(from: before, to: after)
        #expect(changes.count == 2)
        #expect(changes.contains { $0.field == .amount })
        #expect(changes.contains { $0.field == .note })
    }

    @Test("store append and fetch by transaction")
    func storeRoundTrip() throws {
        let defaults = UserDefaults(suiteName: "TransactionEditHistoryTests") ?? .standard
        defaults.removePersistentDomain(forName: "TransactionEditHistoryTests")
        let store = UserDefaultsTransactionEditHistoryStore(userDefaults: defaults)
        let transactionID = UUID()
        let record = TransactionEditRecord(
            transactionID: transactionID,
            changes: [TransactionFieldChange(field: .amount, previousValue: "10", newValue: "20")]
        )

        try store.append(record)
        let fetched = try store.fetch(for: transactionID)
        #expect(fetched.count == 1)
        #expect(fetched.first?.changes.first?.field == .amount)

        try store.delete(for: transactionID)
        #expect(try store.fetch(for: transactionID).isEmpty)
    }

    @Test("store caps history at maxRecordsPerTransaction per transaction")
    func storeCapsPerTransaction() throws {
        let defaults = UserDefaults(suiteName: "TransactionEditHistoryCapTests") ?? .standard
        defaults.removePersistentDomain(forName: "TransactionEditHistoryCapTests")
        let store = UserDefaultsTransactionEditHistoryStore(userDefaults: defaults)
        let transactionID = UUID()
        let cap = TransactionEditHistoryStore.maxRecordsPerTransaction

        for index in 0..<(cap + 5) {
            let record = TransactionEditRecord(
                transactionID: transactionID,
                editedAt: Date(timeIntervalSince1970: Double(index)),
                changes: [TransactionFieldChange(field: .amount, previousValue: "\(index)", newValue: "\(index + 1)")]
            )
            try store.append(record)
        }

        let fetched = try store.fetch(for: transactionID)
        #expect(fetched.count == cap)
        #expect(fetched.first?.editedAt == Date(timeIntervalSince1970: Double(cap + 4)))
    }

    @Test("record edit use case writes on update")
    func recordEditUseCase() throws {
        let defaults = UserDefaults(suiteName: "RecordEditUseCaseTests") ?? .standard
        defaults.removePersistentDomain(forName: "RecordEditUseCaseTests")
        let store = UserDefaultsTransactionEditHistoryStore(userDefaults: defaults)
        let useCase = RecordTransactionEditUseCase(store: store)
        let id = UUID()
        let before = TransactionEntity(id: id, amount: 50, type: .expense, accountID: UUID())
        var after = before
        after.amount = 75

        try useCase.execute(before: before, after: after)
        let history = try store.fetch(for: id)
        #expect(history.count == 1)
    }
}

@Suite("Saved Transaction Filters")
@MainActor
struct SavedTransactionFilterTests {
    @Test("save load and delete preset")
    func presetCRUD() throws {
        let defaults = UserDefaults(suiteName: "SavedTransactionFilterTests") ?? .standard
        defaults.removePersistentDomain(forName: "SavedTransactionFilterTests")
        let store = UserDefaultsSavedTransactionFilterStore(userDefaults: defaults)
        let useCase = ManageSavedTransactionFiltersUseCase(store: store)
        let snapshot = TransactionFilterSnapshot(
            startDate: nil,
            endDate: nil,
            selectedTypeRaws: [TransactionType.expense.rawValue],
            amountMin: "10",
            amountMax: "",
            datePresetRaw: "This Month"
        )

        let saved = try useCase.save(name: "Expenses this month", snapshot: snapshot)
        #expect(try useCase.fetchAll().contains { $0.id == saved.id })

        try useCase.delete(id: saved.id)
        #expect(try useCase.fetchAll().isEmpty)
    }

    @Test("snapshot round-trips through filter view model")
    func snapshotRoundTrip() {
        let vm = TransactionFilterViewModel()
        vm.selectedTypes = [.expense]
        vm.amountMin = "25"
        vm.datePreset = .thisWeek
        vm.applyDatePreset(.thisWeek)

        let snapshot = vm.makeSnapshot()
        let restored = TransactionFilterViewModel()
        restored.applySnapshot(snapshot)

        #expect(restored.selectedTypes == vm.selectedTypes)
        #expect(restored.amountMin == vm.amountMin)
        #expect(restored.datePreset == vm.datePreset)
    }
}

@Suite("BatchScanUseCase")
@MainActor
struct BatchScanUseCaseTests {
    private struct MockOCR: OCRServiceProtocol {
        func scanReceipt(from image: CGImage) async throws -> ReceiptData {
            ReceiptData(
                totalAmount: 42,
                date: .now,
                merchantName: "Test",
                lineItems: [],
                rawText: "TOTAL 42.00"
            )
        }

        func extractText(from image: CGImage) async throws -> [RecognizedTextBlock] {
            []
        }
    }

    @Test("scanReceipts preserves input order")
    func scanOrder() async throws {
        let useCase = BatchScanUseCase(ocrService: MockOCR())
        let image = try #require(makeTestImage())
        let outcome = await useCase.scanReceipts(from: [image, image])
        #expect(outcome.receipts.count == 2)
        #expect(outcome.failureCount == 0)
        #expect(outcome.receipts.allSatisfy { $0.totalAmount == 42 })
    }

    @Test("scanReceipts continues when one image fails")
    func scanPartialSuccess() async throws {
        let useCase = BatchScanUseCase(ocrService: FlakyOCR())
        let goodImage = try #require(makeTestImage(width: 8))
        let badImage = try #require(makeTestImage(width: 1))
        let outcome = await useCase.scanReceipts(from: [goodImage, badImage, goodImage])
        #expect(outcome.receipts.count == 2)
        #expect(outcome.failureCount == 1)
    }

    private struct FlakyOCR: OCRServiceProtocol {
        func scanReceipt(from image: CGImage) async throws -> ReceiptData {
            if image.width <= 1 {
                throw DocumentError.ocrFailed("simulated failure")
            }
            return ReceiptData(
                totalAmount: 42,
                date: .now,
                merchantName: "Test",
                lineItems: [],
                rawText: "TOTAL 42.00"
            )
        }

        func extractText(from image: CGImage) async throws -> [RecognizedTextBlock] {
            []
        }
    }

    private func makeTestImage(width: Int = 8) -> CGImage? {
        #if canImport(UIKit)
        let size = CGSize(width: width, height: 8)
        UIGraphicsBeginImageContext(size)
        defer { UIGraphicsEndImageContext() }
        UIColor.white.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext()?.cgImage
        #elseif canImport(AppKit)
        let image = NSImage(size: NSSize(width: width, height: 8))
        image.lockFocus()
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: width, height: 8).fill()
        image.unlockFocus()
        return image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        #else
        return nil
        #endif
    }
}

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

import Foundation
import SwiftData
import Testing
import VittoraCore
@testable import Vittora

/// Import from Apple Wallet (M3.7.1): the rules, against a real in-memory
/// store.
///
/// FinanceKit itself needs a device, the managed entitlement and real Wallet
/// data. Everything it hands over becomes these records, so this is where a
/// wrong type, a duplicate or an imported UK bank account would come from.
@Suite("Apple Wallet import")
@MainActor
struct AppleWalletImportTests {

    private let card = WalletAccountRecord(id: UUID(), name: "Apple Card", currencyCode: "USD", isLiability: true)
    private let cash = WalletAccountRecord(id: UUID(), name: "Apple Cash", currencyCode: "USD", isLiability: false)
    private let ukBank = WalletAccountRecord(id: UUID(), name: "Monzo", currencyCode: "GBP", isLiability: false)

    private func money(_ text: String) -> Decimal { Decimal(string: text) ?? .nan }

    private func record(
        _ account: WalletAccountRecord,
        _ amount: String,
        _ direction: WalletTransactionRecord.Direction = .debit,
        kind: WalletTransactionRecord.Kind = .spending,
        status: WalletTransactionRecord.Status = .booked,
        merchant: String? = "Blue Bottle",
        id: UUID = UUID()
    ) -> WalletTransactionRecord {
        WalletTransactionRecord(
            id: id, accountID: account.id, amount: money(amount), currencyCode: account.currencyCode,
            direction: direction, kind: kind, status: status,
            date: Date(timeIntervalSince1970: 1_790_000_000), merchantName: merchant,
            description: "BLUE BOTTLE COFFEE SF"
        )
    }

    private struct Harness {
        let useCase: ImportAppleWalletTransactionsUseCase
        let transactions: SwiftDataTransactionRepository
        let accounts: SwiftDataAccountRepository
        let payees: SwiftDataPayeeRepository
    }

    private func makeHarness() throws -> Harness {
        let container = try ModelContainerConfig.makePreviewContainer()
        let accounts = SwiftDataAccountRepository(modelContainer: container)
        let transactions = SwiftDataTransactionRepository(modelContainer: container)
        let payees = SwiftDataPayeeRepository(modelContainer: container)
        let useCase = ImportAppleWalletTransactionsUseCase(
            addTransactionUseCase: AddTransactionUseCase(
                accountRepository: accounts,
                categoryRepository: SwiftDataCategoryRepository(modelContainer: container),
                ledgerWriting: LedgerWriteStore(modelContainer: container)
            ),
            transactionRepository: transactions,
            accountRepository: accounts,
            payeeRepository: payees
        )
        return Harness(useCase: useCase, transactions: transactions, accounts: accounts, payees: payees)
    }

    // MARK: Mapping

    @Test("money out is an expense; refunds and interest are income; payments in are adjustments; transfers out are skipped")
    func ledgerTypes() {
        typealias UseCase = ImportAppleWalletTransactionsUseCase
        #expect(UseCase.ledgerType(for: record(card, "10")) == .expense)
        #expect(UseCase.ledgerType(for: record(card, "10", .credit, kind: .refund)) == .income)
        #expect(UseCase.ledgerType(for: record(cash, "1", .credit, kind: .earning)) == .income)
        // A card payment restores the balance but is not income.
        #expect(UseCase.ledgerType(for: record(card, "500", .credit, kind: .movement)) == .adjustment)
        // Moving Apple Cash to a bank is not spending.
        #expect(UseCase.ledgerType(for: record(cash, "50", .debit, kind: .movement)) == nil)
    }

    // MARK: Planning

    @Test("the plan skips pending, transfers out, duplicates and UK bank accounts, and counts them")
    func planSkips() {
        let repeatID = UUID()
        let alreadyImported = record(card, "4")
        let plan = ImportAppleWalletTransactionsUseCase.plan(
            [
                record(card, "12.50", id: repeatID),
                record(card, "12.50", id: repeatID),                 // same transaction twice in one batch
                alreadyImported,
                record(card, "8", status: .pending),
                record(card, "8", status: .rejected),                 // dropped, not reported
                record(cash, "50", .debit, kind: .movement),
                record(ukBank, "20"),                                  // never imported, never counted
                record(card, "0"),
            ],
            accounts: [card, cash, ukBank],
            existingExternalIDs: [alreadyImported.externalID]
        )
        #expect(plan.accepted.map(\.record.id) == [repeatID])
        #expect(plan.result.skippedDuplicateCount == 2)
        #expect(plan.result.skippedPendingCount == 1)
        #expect(plan.result.skippedTransferCount == 1)
    }

    // MARK: Importing

    @Test("an import lands as ordinary transactions in a new, clearly named account")
    func importsIntoNamedAccount() async throws {
        let harness = try makeHarness()
        let purchase = record(card, "12.50")
        let payment = record(card, "100", .credit, kind: .movement, merchant: nil)

        let (result, links) = try await harness.useCase.execute([purchase, payment], accounts: [card], links: [:])

        #expect(result.importedCount == 2)
        #expect(result.createdAccountNames == ["Apple Card"])
        let account = try #require(try await harness.accounts.fetchAll().first { $0.name == "Apple Card" })
        #expect(account.type == .creditCard)
        #expect(links[card.id] == account.id)

        let imported = try await harness.transactions.fetchAll(filter: nil)
        let expense = try #require(imported.first { $0.type == .expense })
        #expect(expense.amount == money("12.50"))
        #expect(expense.accountID == account.id)
        #expect(expense.externalID == purchase.externalID)
        #expect(expense.note == "BLUE BOTTLE COFFEE SF")
        #expect(try await harness.payees.fetchAll().map(\.name) == ["Blue Bottle"])
        #expect(imported.contains { $0.type == .adjustment && $0.payeeID == nil })
        // Card: −12.50 spent, +100 paid.
        #expect(try await harness.accounts.fetchByID(account.id)?.balance == money("87.50"))
    }

    /// The acceptance criterion: re-import must not duplicate — including
    /// after the user moved a row to another account.
    @Test("importing the same transactions again adds nothing")
    func reimportIsIdempotent() async throws {
        let harness = try makeHarness()
        let records = [record(card, "12.50"), record(card, "3.20", merchant: "Muni")]
        let first = try await harness.useCase.execute(records, accounts: [card], links: [:])

        // The user moves one imported row to a different account.
        let other = AccountEntity(name: "Checking", type: .bank, currencyCode: "USD")
        try await harness.accounts.create(other)
        var moved = try #require(try await harness.transactions.fetchAll(filter: nil).first)
        moved.accountID = other.id
        try await harness.transactions.update(moved)

        let second = try await harness.useCase.execute(records, accounts: [card], links: first.links)

        #expect(second.result.importedCount == 0)
        #expect(second.result.skippedDuplicateCount == 2)
        #expect(try await harness.transactions.fetchAll(filter: nil).count == 2)
    }

    @Test("an existing account with the Wallet name is reused, not duplicated")
    func reusesNamedAccount() async throws {
        let harness = try makeHarness()
        let existing = AccountEntity(name: "apple card", type: .creditCard, currencyCode: "USD")
        try await harness.accounts.create(existing)

        let (result, links) = try await harness.useCase.execute([record(card, "5")], accounts: [card], links: [:])

        #expect(result.createdAccountNames.isEmpty)
        #expect(links[card.id] == existing.id)
        #expect(try await harness.accounts.fetchAll().count == 1)
    }

    /// Rows entered in the app keep a random `externalID` from before import
    /// existed; the prefix query must never mistake them for imports.
    @Test("the external ID query only returns imported rows")
    func externalIDQueryIsPrefixed() async throws {
        let harness = try makeHarness()
        try await harness.transactions.create(TransactionEntity(amount: 1, currencyCode: "USD"))
        _ = try await harness.useCase.execute([record(card, "5")], accounts: [card], links: [:])

        let ids = try await harness.transactions.fetchExternalIDs(withPrefix: ImportAppleWalletTransactionsUseCase.externalIDPrefix)
        #expect(ids.count == 1)
        #expect(ids.allSatisfy { $0.hasPrefix("financekit:") })
    }
}

#if os(iOS)
import FinanceKit

/// The FinanceKit → record translation. The direction decides a bill payment:
/// paying a bill from Apple Cash is spending, a payment arriving on Apple Card
/// is money moving between the user's own accounts.
@Suite("Apple Wallet FinanceKit mapping")
struct AppleWalletFinanceKitMappingTests {
    @Test("transaction kinds follow type and direction")
    func kinds() {
        #expect(AppleWalletService.kind(of: .pointOfSale, direction: .debit) == .spending)
        #expect(AppleWalletService.kind(of: .refund, direction: .credit) == .refund)
        #expect(AppleWalletService.kind(of: .interest, direction: .credit) == .earning)
        #expect(AppleWalletService.kind(of: .transfer, direction: .debit) == .movement)
        #expect(AppleWalletService.kind(of: .billPayment, direction: .credit) == .movement)
        #expect(AppleWalletService.kind(of: .billPayment, direction: .debit) == .spending)
    }

    /// Found by this test's first version: on the simulator
    /// `isDataAvailable(.financialData)` is TRUE, and without the entitlement
    /// the next FinanceKit call traps. The unentitled build must report
    /// "unavailable" and never reach FinanceKit — if this crashes, a user's
    /// app would too.
    @Test("without the entitlement, FinanceKit is never reached")
    @MainActor
    func unentitledNeverQueries() async throws {
        #expect(!AppleWalletService.isEntitled, "precondition: this build has no FinanceKit entitlement")
        let service = AppleWalletService.shared
        await service.refreshAvailability()
        #expect(service.availability == .unavailable)
        #expect(try await service.accounts().isEmpty)
        #expect(try await service.recentTransactions(days: 30).isEmpty)
    }

    @Test("only booked transactions count as booked")
    func statuses() {
        #expect(AppleWalletService.status(of: .booked) == .booked)
        #expect(AppleWalletService.status(of: .pending) == .pending)
        #expect(AppleWalletService.status(of: .authorized) == .pending)
        #expect(AppleWalletService.status(of: .memo) == .pending)
        #expect(AppleWalletService.status(of: .rejected) == .rejected)
    }
}
#endif

/// The Info.plist flag that unlocks FinanceKit and the entitlement it stands
/// for must change together: flag without entitlement traps inside FinanceKit
/// on the first call; entitlement without flag ships a feature nobody sees.
@Suite("Apple Wallet entitlement flag")
struct AppleWalletEntitlementTests {
    private func plist(_ relativePath: String) throws -> [String: Any] {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: root.appendingPathComponent(relativePath))
        return try #require(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
    }

    @Test("VittoraFinanceKitEnabled matches the FinanceKit entitlement")
    func flagMatchesEntitlement() throws {
        let flag = try plist("Vittora/Info.plist")["VittoraFinanceKitEnabled"] as? Bool ?? false
        let entitled = try plist("Vittora/Vittora.entitlements")["com.apple.developer.financekit"] != nil
        #expect(flag == entitled)
    }
}

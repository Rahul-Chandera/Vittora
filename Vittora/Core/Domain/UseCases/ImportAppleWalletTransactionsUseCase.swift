import Foundation
import VittoraCore

/// Import from Apple Wallet (M3.7.1): Apple Card, Apple Cash and Savings
/// transactions into the ordinary ledger.
///
/// Works on plain records rather than FinanceKit types, so every rule here —
/// what is imported, as what, into which account, and what is skipped — is
/// testable without a device, an entitlement or real Wallet data.
/// `AppleWalletService` converts FinanceKit's types into these records.

/// A Wallet account as FinanceKit describes it.
nonisolated struct WalletAccountRecord: Sendable, Equatable {
    let id: UUID
    let name: String
    let currencyCode: String
    /// Apple Card is a liability; Apple Cash and Savings are assets.
    let isLiability: Bool

    /// US Wallet products only (handoff rule 2). UK open-banking accounts that
    /// FinanceKit can also surface are in pounds, and must never be imported
    /// or shown as if this were bank sync.
    var isSupported: Bool { currencyCode.uppercased() == "USD" }

    var ledgerAccountType: AccountType {
        if isLiability { return .creditCard }
        return name.localizedCaseInsensitiveContains("cash") ? .digitalWallet : .bank
    }
}

/// A Wallet transaction as FinanceKit describes it.
nonisolated struct WalletTransactionRecord: Sendable, Equatable {
    enum Direction: Sendable { case credit, debit }
    enum Status: Sendable { case booked, pending, rejected }
    /// FinanceKit's transaction types, reduced to what changes the mapping.
    enum Kind: Sendable { case spending, refund, earning, movement }

    let id: UUID
    let accountID: UUID
    let amount: Decimal
    let currencyCode: String
    let direction: Direction
    let kind: Kind
    let status: Status
    let date: Date
    let merchantName: String?
    let description: String

    var externalID: String { ImportAppleWalletTransactionsUseCase.externalIDPrefix + id.uuidString }
}

nonisolated struct AppleWalletImportResult: Sendable, Equatable {
    var importedCount = 0
    var skippedDuplicateCount = 0
    /// Not yet posted. They import once they are — pending amounts can still
    /// change, and a row imported early would keep the wrong one.
    var skippedPendingCount = 0
    /// Money moved between the user's own accounts in a way the ledger can't
    /// express one-sided — see `ledgerType(for:)`.
    var skippedTransferCount = 0
    var createdAccountNames: [String] = []
}

struct ImportAppleWalletTransactionsUseCase: Sendable {
    nonisolated static let externalIDPrefix = "financekit:"

    let addTransactionUseCase: AddTransactionUseCase
    let transactionRepository: any TransactionRepository
    let accountRepository: any AccountRepository
    let payeeRepository: any PayeeRepository

    /// How a Wallet transaction lands in the ledger, or nil to skip it.
    ///
    /// - Money out (purchases, fees, ATM) is an expense.
    /// - Refunds, interest and Daily Cash are income.
    /// - A card payment or top-up coming IN is an adjustment: it restores the
    ///   account balance without counting as income, which would double the
    ///   user's salary in every report.
    /// - A transfer going OUT (Apple Cash to a bank) is skipped: the ledger's
    ///   adjustments only add, and recording it as an expense would count
    ///   moving your own money as spending. The count is reported so the
    ///   user can add it as a transfer.
    nonisolated static func ledgerType(for record: WalletTransactionRecord) -> TransactionType? {
        switch (record.direction, record.kind) {
        case (.debit, .movement): nil
        case (.debit, _): .expense
        case (.credit, .movement): .adjustment
        case (.credit, _): .income
        }
    }

    /// What an import would bring in, and what it would skip and why. Pure:
    /// the preview screen shows exactly this before anything is written.
    nonisolated static func plan(
        _ records: [WalletTransactionRecord],
        accounts: [WalletAccountRecord],
        existingExternalIDs: Set<String>
    ) -> (accepted: [(record: WalletTransactionRecord, type: TransactionType)], result: AppleWalletImportResult) {
        var result = AppleWalletImportResult()
        let supportedIDs = Set(accounts.filter(\.isSupported).map(\.id))
        var seen = existingExternalIDs
        var accepted: [(record: WalletTransactionRecord, type: TransactionType)] = []
        for record in records {
            guard supportedIDs.contains(record.accountID) else { continue }
            guard record.status == .booked else {
                if record.status == .pending { result.skippedPendingCount += 1 }
                continue
            }
            guard let type = ledgerType(for: record) else {
                result.skippedTransferCount += 1
                continue
            }
            guard record.amount > 0 else { continue }
            guard seen.insert(record.externalID).inserted else {
                result.skippedDuplicateCount += 1
                continue
            }
            accepted.append((record, type))
        }
        return (accepted, result)
    }

    /// Imports what is new and returns the result together with the
    /// FinanceKit → ledger account links to persist for next time.
    func execute(
        _ records: [WalletTransactionRecord],
        accounts: [WalletAccountRecord],
        links: [UUID: UUID]
    ) async throws -> (result: AppleWalletImportResult, links: [UUID: UUID]) {
        var links = links
        let existing = try await transactionRepository.fetchExternalIDs(withPrefix: Self.externalIDPrefix)
        let plan = Self.plan(records, accounts: accounts, existingExternalIDs: existing)
        var result = plan.result
        let accepted = plan.accepted
        let supported = Dictionary(
            accounts.filter(\.isSupported).map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        guard !accepted.isEmpty else { return (result, links) }

        // Ledger accounts: the linked one, else one already named after the
        // Wallet account, else a new one — never a silent merge into some
        // unrelated account.
        var ledgerAccounts = try await accountRepository.fetchAll()
        var ledgerAccountByWallet: [UUID: UUID] = [:]
        for walletID in Set(accepted.map(\.record.accountID)) {
            guard let wallet = supported[walletID] else { continue }
            if let linked = links[walletID],
               ledgerAccounts.contains(where: { $0.id == linked && !$0.isArchived }) {
                ledgerAccountByWallet[walletID] = linked
            } else if let named = ledgerAccounts.first(where: {
                !$0.isArchived && $0.name.caseInsensitiveCompare(wallet.name) == .orderedSame
            }) {
                ledgerAccountByWallet[walletID] = named.id
            } else {
                let created = AccountEntity(
                    name: wallet.name,
                    type: wallet.ledgerAccountType,
                    currencyCode: wallet.currencyCode,
                    icon: wallet.isLiability ? "creditcard.fill" : "wallet.bifold.fill"
                )
                try await accountRepository.create(created)
                ledgerAccounts.append(created)
                ledgerAccountByWallet[walletID] = created.id
                result.createdAccountNames.append(created.name)
            }
            links[walletID] = ledgerAccountByWallet[walletID]
        }

        // Payees by merchant name, reusing existing ones like CSV import does.
        var payeesByName = Dictionary(
            try await payeeRepository.fetchAll().map { ($0.name.lowercased(), $0.id) },
            uniquingKeysWith: { first, _ in first }
        )
        let categoryByPayee = try await usualCategoryByPayee()

        var byAccount: [UUID: [TransactionEntity]] = [:]
        for (record, type) in accepted {
            guard let accountID = ledgerAccountByWallet[record.accountID] else { continue }
            let payeeID = try await resolvePayee(record.merchantName, lookup: &payeesByName)
            let description = record.description.trimmingCharacters(in: .whitespacesAndNewlines)
            byAccount[accountID, default: []].append(TransactionEntity(
                amount: record.amount,
                date: record.date,
                note: description.isEmpty ? nil : description,
                type: type,
                paymentMethod: .other,
                currencyCode: record.currencyCode,
                // Best effort, never blocking: what this payee is usually
                // filed under. Adjustments carry no category.
                categoryID: type == .adjustment ? nil : payeeID.flatMap { categoryByPayee[$0] },
                accountID: accountID,
                payeeID: payeeID,
                externalID: record.externalID
            ))
        }

        for (_, transactions) in byAccount {
            try await addTransactionUseCase.executeBatch(transactions)
            result.importedCount += transactions.count
        }
        return (result, links)
    }

    private func resolvePayee(_ merchantName: String?, lookup: inout [String: UUID]) async throws -> UUID? {
        let name = (merchantName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        if let existing = lookup[name.lowercased()] { return existing }
        let payee = PayeeEntity(name: name, type: .business)
        try await payeeRepository.create(payee)
        lookup[name.lowercased()] = payee.id
        return payee.id
    }

    /// Each payee's most-used category across the ledger.
    private func usualCategoryByPayee() async throws -> [UUID: UUID] {
        var counts: [UUID: [UUID: Int]] = [:]
        for transaction in try await transactionRepository.fetchAll(filter: nil) {
            guard let payeeID = transaction.payeeID, let categoryID = transaction.categoryID else { continue }
            counts[payeeID, default: [:]][categoryID, default: 0] += 1
        }
        return counts.compactMapValues { tally in
            // Ties broken by UUID so the choice is stable between imports.
            tally.max { ($0.value, $1.key.uuidString) < ($1.value, $0.key.uuidString) }?.key
        }
    }
}

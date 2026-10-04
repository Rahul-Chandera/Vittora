import Foundation
import Testing
import VittoraCore
@testable import Vittora

/// How the Debt Ledger splits payees between "Owed to You" and "You Owe".
///
/// The sections used to filter on the gross totals (`totalLent > 0`,
/// `totalBorrowed > 0`) while `DebtRowView` displayed `abs(netBalance)`. Anyone
/// with debt running both ways therefore appeared in BOTH sections, each row
/// showing the same net figure, and the copy under "Owed to You" was drawn in
/// the you-owe colour because the net was negative.
///
/// Seen on iPhone 17 Pro Max / iOS 26.5 with the seeded payee who owes 150 and
/// is owed 300: two rows, both reading $150.00, both red.
@Suite("Debt ledger sections")
@MainActor
struct DebtLedgerSectionsTests {

    private func entry(_ name: String, lent: Decimal, borrowed: Decimal) -> DebtLedgerEntry {
        DebtLedgerEntry(
            payee: PayeeEntity(name: name),
            entries: [],
            totalLent: lent,
            totalBorrowed: borrowed
        )
    }

    private func viewModel(_ entries: [DebtLedgerEntry]) -> DebtLedgerViewModel {
        let debts = MockDebtRepository()
        let payees = MockPayeeRepository()
        let vm = DebtLedgerViewModel(
            fetchLedgerUseCase: FetchDebtLedgerUseCase(
                debtRepository: debts, payeeRepository: payees
            ),
            calculateBalanceUseCase: CalculateDebtBalanceUseCase(debtRepository: debts),
            fetchOverdueUseCase: FetchOverdueDebtsUseCase(debtRepository: debts)
        )
        vm.ledgerEntries = entries
        return vm
    }

    /// The regression: one payee, one section.
    @Test("a payee with debt both ways appears once, on the side they net out to")
    func bothDirectionsAppearsOnce() {
        let vm = viewModel([entry("Alex Carter", lent: 150, borrowed: 300)])

        #expect(vm.owedToMeEntries.isEmpty)
        #expect(vm.iOweEntries.count == 1)
        #expect(vm.iOweEntries.first?.netBalance == -150)
    }

    @Test("netting the other way puts them on the other side")
    func netPositivePayeeIsOwedToYou() {
        let vm = viewModel([entry("Priya", lent: 900, borrowed: 250)])

        #expect(vm.iOweEntries.isEmpty)
        #expect(vm.owedToMeEntries.count == 1)
        #expect(vm.owedToMeEntries.first?.netBalance == 650)
    }

    /// Square with you is not "owed" in either direction. Under the old filter
    /// this payee appeared in both sections, each row reading $0.00.
    @Test("a settled payee appears in neither section")
    func squarePayeeIsInNeitherSection() {
        let vm = viewModel([entry("Sam", lent: 150, borrowed: 150)])

        #expect(vm.owedToMeEntries.isEmpty)
        #expect(vm.iOweEntries.isEmpty)
    }

    @Test("one-directional payees land where they always did")
    func oneDirectionalPayeesAreUnaffected() {
        let vm = viewModel([
            entry("Lends", lent: 500, borrowed: 0),
            entry("Borrows", lent: 0, borrowed: 400),
        ])

        #expect(vm.owedToMeEntries.map(\.payee.name) == ["Lends"])
        #expect(vm.iOweEntries.map(\.payee.name) == ["Borrows"])
    }

    /// No payee may be listed twice, whatever the mix.
    @Test("the two sections never share a payee")
    func sectionsAreDisjoint() {
        let vm = viewModel([
            entry("Both ways", lent: 150, borrowed: 300),
            entry("Other way", lent: 900, borrowed: 250),
            entry("Square", lent: 100, borrowed: 100),
            entry("Lends only", lent: 500, borrowed: 0),
        ])

        let owed = Set(vm.owedToMeEntries.map(\.id))
        let owing = Set(vm.iOweEntries.map(\.id))
        #expect(owed.intersection(owing).isEmpty)
    }
}

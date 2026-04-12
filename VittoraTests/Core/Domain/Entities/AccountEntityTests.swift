import Foundation
import Testing

@testable import Vittora

@Suite("AccountEntity Tests")
struct AccountEntityTests {
    @Test("AccountType.isAsset for asset accounts")
    func testAccountTypeIsAssetForAssets() {
        #expect(AccountType.cash.isAsset == true)
        #expect(AccountType.bank.isAsset == true)
        #expect(AccountType.digitalWallet.isAsset == true)
        #expect(AccountType.investment.isAsset == true)
        #expect(AccountType.receivable.isAsset == true)
    }

    @Test("AccountType.isAsset for liability accounts")
    func testAccountTypeIsAssetForLiabilities() {
        #expect(AccountType.creditCard.isAsset == false)
        #expect(AccountType.loan.isAsset == false)
        #expect(AccountType.payable.isAsset == false)
    }

    @Test("Default initializer values")
    func testDefaultInitializerValues() {
        let entity = AccountEntity(
            name: "My Bank",
            type: .bank
        )

        #expect(entity.name == "My Bank")
        #expect(entity.type == .bank)
        #expect(entity.balance == Decimal(0))
        #expect(entity.currencyCode == "USD")
        #expect(entity.icon == "building.columns.fill")
        #expect(entity.isArchived == false)
    }

    @Test("Custom initializer values")
    func testCustomInitializerValues() {
        let balance = Decimal(5000.0)
        let entity = AccountEntity(
            name: "Savings",
            type: .bank,
            balance: balance,
            currencyCode: "EUR",
            icon: "piggybank.fill",
            isArchived: true
        )

        #expect(entity.name == "Savings")
        #expect(entity.type == .bank)
        #expect(entity.balance == balance)
        #expect(entity.currencyCode == "EUR")
        #expect(entity.icon == "piggybank.fill")
        #expect(entity.isArchived == true)
    }

    @Test("All account types are initialized correctly")
    func testAllAccountTypesInitialization() {
        let types: [AccountType] = [.cash, .bank, .creditCard, .loan, .digitalWallet, .investment, .receivable, .payable]

        for type in types {
            let entity = AccountEntity(
                name: "Test Account",
                type: type
            )
            #expect(entity.type == type)
        }
    }

    @Test("Identifiable conformance")
    func testIdentifiable() {
        let id = UUID()
        let entity = AccountEntity(
            id: id,
            name: "Test",
            type: .bank
        )

        #expect(entity.id == id)
    }

    @Test("Equatable conformance")
    func testEquatable() {
        let id = UUID()
        let entity1 = AccountEntity(
            id: id,
            name: "Test",
            type: .bank,
            balance: Decimal(1000.0)
        )
        let entity2 = AccountEntity(
            id: id,
            name: "Test",
            type: .bank,
            balance: Decimal(1000.0)
        )

        #expect(entity1 == entity2)
    }

    @Test("Not equal when different ids")
    func testNotEqualWithDifferentIds() {
        let entity1 = AccountEntity(
            name: "Test",
            type: .bank,
            balance: Decimal(1000.0)
        )
        let entity2 = AccountEntity(
            name: "Test",
            type: .bank,
            balance: Decimal(1000.0)
        )

        #expect(entity1 != entity2)
    }

    @Test("Hashable conformance")
    func testHashable() {
        let id = UUID()
        let entity1 = AccountEntity(
            id: id,
            name: "Test",
            type: .bank
        )
        let entity2 = AccountEntity(
            id: id,
            name: "Test",
            type: .bank
        )

        var set: Set<AccountEntity> = [entity1]
        set.insert(entity2)

        #expect(set.count == 1)
    }

    @Test("Sendable conformance")
    func testSendableConformance() {
        let entity = AccountEntity(
            name: "Test",
            type: .bank
        )

        #expect(entity.type == .bank)
        #expect(entity.currencyCode == "USD")
    }
}

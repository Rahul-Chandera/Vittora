import Foundation
import Testing
import SwiftData

@testable import Vittora

@Suite("AccountMapper Tests")
struct AccountMapperTests {
    @Test("toEntity maps all fields correctly")
    func testToEntityMapsAllFields() {
        let id = UUID()
        let name = "Checking Account"
        let balance = Decimal(5000.0)
        let currencyCode = "EUR"
        let icon = "building.columns.fill"
        let isArchived = true
        let createdAt = Date()
        let updatedAt = Date()

        let model = SDAccount(
            id: id,
            name: name,
            type: .bank,
            balance: balance,
            currencyCode: currencyCode,
            icon: icon,
            isArchived: isArchived,
            createdAt: createdAt,
            updatedAt: updatedAt
        )

        let entity = AccountMapper.toEntity(model)

        #expect(entity.id == id)
        #expect(entity.name == name)
        #expect(entity.type == .bank)
        #expect(entity.balance == balance)
        #expect(entity.currencyCode == currencyCode)
        #expect(entity.icon == icon)
        #expect(entity.isArchived == isArchived)
        #expect(entity.createdAt == createdAt)
        #expect(entity.updatedAt == updatedAt)
    }

    @Test("toEntity maps default values correctly")
    func testToEntityMapsDefaults() {
        let model = SDAccount()
        model.name = "My Account"
        model.type = .bank

        let entity = AccountMapper.toEntity(model)

        #expect(entity.name == "My Account")
        #expect(entity.type == .bank)
        #expect(entity.balance == Decimal(0))
        #expect(entity.currencyCode == "USD")
        #expect(entity.icon == "building.columns.fill")
        #expect(entity.isArchived == false)
    }

    @Test("toEntity with all account types")
    func testToEntityWithAllAccountTypes() {
        let types: [AccountType] = [.cash, .bank, .creditCard, .loan, .digitalWallet, .investment, .receivable, .payable]

        for type in types {
            let model = SDAccount()
            model.name = "Test"
            model.type = type

            let entity = AccountMapper.toEntity(model)

            #expect(entity.type == type)
        }
    }

    @Test("updateModel modifies all fields")
    func testUpdateModelModifiesAllFields() {
        let model = SDAccount()
        let originalID = model.id
        let originalCreatedAt = model.createdAt

        let entity = AccountEntity(
            name: "Updated Account",
            type: .creditCard,
            balance: Decimal(10000.0),
            currencyCode: "GBP",
            icon: "creditcard.fill",
            isArchived: true
        )

        AccountMapper.updateModel(model, from: entity)

        #expect(model.id == originalID)
        #expect(model.name == "Updated Account")
        #expect(model.type == .creditCard)
        #expect(model.balance == Decimal(10000.0))
        #expect(model.currencyCode == "GBP")
        #expect(model.icon == "creditcard.fill")
        #expect(model.isArchived == true)
        #expect(model.createdAt == originalCreatedAt)
        #expect(model.updatedAt > originalCreatedAt)
    }

    @Test("updateModel preserves id and timestamps")
    func testUpdateModelPreservesIdAndTimestamps() {
        let originalID = UUID()
        let originalCreatedAt = Date().addingTimeInterval(-1000)
        let model = SDAccount()
        model.id = originalID
        model.createdAt = originalCreatedAt
        model.name = "Original"

        let entity = AccountEntity(
            name: "Updated",
            type: .bank
        )

        AccountMapper.updateModel(model, from: entity)

        #expect(model.id == originalID)
        #expect(model.createdAt == originalCreatedAt)
        #expect(model.updatedAt > originalCreatedAt)
    }

    @Test("Round-trip mapping preserves data")
    func testRoundTripMapping() {
        let name = "Savings Account"
        let type = AccountType.bank
        let balance = Decimal(25000.0)
        let currencyCode = "CAD"
        let icon = "piggybank.fill"

        let model = SDAccount(
            name: name,
            type: type,
            balance: balance,
            currencyCode: currencyCode,
            icon: icon
        )

        let entity = AccountMapper.toEntity(model)

        #expect(entity.name == name)
        #expect(entity.type == type)
        #expect(entity.balance == balance)
        #expect(entity.currencyCode == currencyCode)
        #expect(entity.icon == icon)
    }

    @Test("toEntity with zero balance")
    func testToEntityWithZeroBalance() {
        let model = SDAccount()
        model.name = "New Account"
        model.type = .bank
        model.balance = Decimal(0)

        let entity = AccountMapper.toEntity(model)

        #expect(entity.balance == Decimal(0))
    }

    @Test("toEntity with negative balance")
    func testToEntityWithNegativeBalance() {
        let model = SDAccount()
        model.name = "Overdraft"
        model.type = .bank
        model.balance = Decimal(-500.0)

        let entity = AccountMapper.toEntity(model)

        #expect(entity.balance == Decimal(-500.0))
    }

    @Test("updateModel with different currencies")
    func testUpdateModelWithDifferentCurrencies() {
        let currencies = ["USD", "EUR", "GBP", "INR", "JPY"]

        for currency in currencies {
            let model = SDAccount()
            model.currencyCode = "USD"

            let entity = AccountEntity(
                name: "Test",
                type: .bank,
                currencyCode: currency
            )

            AccountMapper.updateModel(model, from: entity)

            #expect(model.currencyCode == currency)
        }
    }

    @Test("updateModel with archived state change")
    func testUpdateModelWithArchivedStateChange() {
        let model = SDAccount()
        model.isArchived = false

        let entity = AccountEntity(
            name: "Test",
            type: .bank,
            isArchived: true
        )

        AccountMapper.updateModel(model, from: entity)

        #expect(model.isArchived == true)
    }

    @Test("toEntity handles different icons")
    func testToEntityHandlesDifferentIcons() {
        let icons = ["building.columns.fill", "piggybank.fill", "creditcard.fill", "wallet.pass.fill"]

        for icon in icons {
            let model = SDAccount()
            model.name = "Test"
            model.type = .bank
            model.icon = icon

            let entity = AccountMapper.toEntity(model)

            #expect(entity.icon == icon)
        }
    }
}

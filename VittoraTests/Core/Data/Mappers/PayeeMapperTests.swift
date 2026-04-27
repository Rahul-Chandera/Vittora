import Foundation
import Testing
import SwiftData

@testable import Vittora

@Suite("PayeeMapper Tests")
struct PayeeMapperTests {

    @Test("toEntity maps all fields correctly")
    func testToEntityMapsAllFields() {
        let id = UUID()
        let name = "Amazon"
        let type = PayeeType.business
        let phone = "+1-800-123-4567"
        let email = "billing@amazon.com"
        let notes = "Prime membership auto-renews annually"
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let updatedAt = Date(timeIntervalSince1970: 1_700_001_000)

        let model = SDPayee(
            id: id,
            name: name,
            type: type,
            phone: phone,
            email: email,
            notes: notes,
            createdAt: createdAt,
            updatedAt: updatedAt
        )

        let entity = PayeeMapper.toEntity(model)

        #expect(entity.id == id)
        #expect(entity.name == name)
        #expect(entity.type == type)
        #expect(entity.phone == phone)
        #expect(entity.email == email)
        #expect(entity.notes == notes)
        #expect(entity.createdAt == createdAt)
        #expect(entity.updatedAt == updatedAt)
    }

    @Test("toEntity maps nil optional fields correctly")
    func testToEntityMapsNilOptionalFields() {
        let model = SDPayee(name: "John Doe", type: .person)

        let entity = PayeeMapper.toEntity(model)

        #expect(entity.phone == nil)
        #expect(entity.email == nil)
        #expect(entity.notes == nil)
    }

    @Test("updateModel modifies mutable fields and stamps updatedAt")
    func testUpdateModelModifiesMutableFields() {
        let model = SDPayee()
        let originalID = model.id
        let originalCreatedAt = model.createdAt

        let entity = PayeeEntity(
            name: "Netflix",
            type: .business,
            phone: nil,
            email: "support@netflix.com",
            notes: "Streaming subscription"
        )

        PayeeMapper.updateModel(model, from: entity)

        #expect(model.id == originalID)
        #expect(model.createdAt == originalCreatedAt)
        #expect(model.name == "Netflix")
        #expect(model.type == .business)
        #expect(model.phone == nil)
        #expect(model.email == "support@netflix.com")
        #expect(model.notes == "Streaming subscription")
        #expect(model.updatedAt > originalCreatedAt)
    }

    @Test("Round-trip mapping preserves all fields")
    func testRoundTripMapping() {
        let id = UUID()
        let createdAt = Date(timeIntervalSince1970: 1_695_000_000)
        let updatedAt = Date(timeIntervalSince1970: 1_695_001_000)

        let model = SDPayee(
            id: id,
            name: "Jane Smith",
            type: .person,
            phone: "+91-9876543210",
            email: "jane@example.com",
            notes: "Flatmate",
            createdAt: createdAt,
            updatedAt: updatedAt
        )

        let entity = PayeeMapper.toEntity(model)
        PayeeMapper.updateModel(model, from: entity)

        #expect(model.id == id)
        #expect(model.name == "Jane Smith")
        #expect(model.type == .person)
        #expect(model.phone == "+91-9876543210")
        #expect(model.email == "jane@example.com")
        #expect(model.notes == "Flatmate")
        #expect(model.createdAt == createdAt)
    }

    @Test("toEntity with both payee types")
    func testToEntityWithBothPayeeTypes() {
        let types: [PayeeType] = [.person, .business]

        for type in types {
            let model = SDPayee(name: "Test", type: type)
            let entity = PayeeMapper.toEntity(model)
            #expect(entity.type == type)
        }
    }

    @Test("updateModel preserves id and createdAt")
    func testUpdateModelPreservesIdAndCreatedAt() {
        let originalID = UUID()
        let originalCreatedAt = Date(timeIntervalSince1970: 1_680_000_000)
        let model = SDPayee()
        model.id = originalID
        model.createdAt = originalCreatedAt

        let entity = PayeeEntity(name: "Updated Payee", type: .business)

        PayeeMapper.updateModel(model, from: entity)

        #expect(model.id == originalID)
        #expect(model.createdAt == originalCreatedAt)
        #expect(model.updatedAt > originalCreatedAt)
    }
}

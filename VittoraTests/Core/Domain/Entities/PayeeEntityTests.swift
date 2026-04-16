import Foundation
import Testing

@testable import Vittora

@MainActor
@Suite("PayeeEntity Tests")
struct PayeeEntityTests {
    @Test("Default initializer values")
    func testDefaultInitializerValues() {
        let entity = PayeeEntity(name: "Apple")

        #expect(entity.name == "Apple")
        #expect(entity.type == .business)
        #expect(entity.phone == nil)
        #expect(entity.email == nil)
        #expect(entity.notes == nil)
    }

    @Test("Custom initializer values with contact info")
    func testCustomInitializerValues() {
        let entity = PayeeEntity(
            name: "John Doe",
            type: .person,
            phone: "+1 555 1234",
            email: "john@example.com",
            notes: "Freelancer"
        )

        #expect(entity.name == "John Doe")
        #expect(entity.type == .person)
        #expect(entity.phone == "+1 555 1234")
        #expect(entity.email == "john@example.com")
        #expect(entity.notes == "Freelancer")
    }

    @Test("PayeeType raw values")
    func testPayeeTypeRawValues() {
        #expect(PayeeType.person.rawValue == "person")
        #expect(PayeeType.business.rawValue == "business")
    }

    @Test("PayeeType CaseIterable")
    func testPayeeTypeAllCases() {
        #expect(PayeeType.allCases.count == 2)
        #expect(PayeeType.allCases.contains(.person))
        #expect(PayeeType.allCases.contains(.business))
    }

    @Test("Identifiable conformance")
    func testIdentifiable() {
        let id = UUID()
        let entity = PayeeEntity(id: id, name: "Test")
        #expect(entity.id == id)
    }

    @Test("Equatable conformance")
    func testEquatable() {
        let id = UUID()
        let entity1 = PayeeEntity(id: id, name: "Apple", type: .business)
        let entity2 = PayeeEntity(id: id, name: "Apple", type: .business)
        #expect(entity1 == entity2)
    }

    @Test("Not equal when IDs differ")
    func testNotEqualWithDifferentIDs() {
        let entity1 = PayeeEntity(name: "Apple", type: .business)
        let entity2 = PayeeEntity(name: "Apple", type: .business)
        #expect(entity1 != entity2)
    }

    @Test("Hashable conformance")
    func testHashable() {
        let id = UUID()
        let entity1 = PayeeEntity(id: id, name: "Apple")
        let entity2 = PayeeEntity(id: id, name: "Apple")

        var set: Set<PayeeEntity> = [entity1]
        set.insert(entity2)
        #expect(set.count == 1)
    }
}

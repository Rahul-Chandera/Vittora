import Foundation
import Testing
import VittoraCore
@testable import Vittora

@Suite("Split Group Deep Link Tests")
struct SplitGroupDeepLinkTests {

    @Test("builds and parses vittora split group URLs")
    func roundTripGroupURL() {
        let groupID = UUID(uuidString: "A1B2C3D4-E5F6-7890-ABCD-EF1234567890") ?? UUID()
        let url = SplitGroupDeepLink.url(for: groupID)

        #expect(url.scheme == "vittora")
        #expect(url.host == "splits")
        #expect(SplitGroupDeepLink.groupID(from: url) == groupID)
    }

    @Test("rejects unrelated URLs")
    func rejectsUnrelatedURLs() {
        #expect(SplitGroupDeepLink.groupID(from: URL(string: "https://example.com")!) == nil)
        #expect(SplitGroupDeepLink.groupID(from: URL(string: "vittora://dashboard")!) == nil)
        #expect(SplitGroupDeepLink.groupID(from: URL(string: "vittora://splits")!) == nil)
    }

    @Test("parses URLs with uppercase scheme and host identically to lowercase")
    func caseInsensitiveSchemeAndHost() {
        let groupID = UUID(uuidString: "A1B2C3D4-E5F6-7890-ABCD-EF1234567890") ?? UUID()
        let url = URL(string: "VITTORA://SPLITS/group/\(groupID.uuidString)")!
        #expect(SplitGroupDeepLink.groupID(from: url) == groupID)
    }

    @Test("returns nil when path segment is not a valid UUID")
    func rejectsMalformedUUID() {
        let url = URL(string: "vittora://splits/group/not-a-uuid")!
        #expect(SplitGroupDeepLink.groupID(from: url) == nil)
    }

    @Test("returns nil when path prefix is wrong")
    func rejectsWrongPathPrefix() {
        let groupID = UUID(uuidString: "A1B2C3D4-E5F6-7890-ABCD-EF1234567890") ?? UUID()
        let url = URL(string: "vittora://splits/member/\(groupID.uuidString)")!
        #expect(SplitGroupDeepLink.groupID(from: url) == nil)
    }
}

@Suite("Split Group Share Draft Tests")
struct SplitGroupShareDraftTests {
    private let currencyCode = "USD"
    private let alice = UUID(uuidString: "11111111-1111-1111-1111-111111111111") ?? UUID()
    private let bob = UUID(uuidString: "22222222-2222-2222-2222-222222222222") ?? UUID()

    @Test("invite message includes group, members, balances, and deep link")
    func inviteMessageIncludesDeepLink() {
        let groupID = UUID(uuidString: "33333333-3333-3333-3333-333333333333") ?? UUID()
        let names: [UUID: String] = [
            alice: "Alice",
            bob: "Bob",
        ]
        let balances = [
            MemberBalance(fromMemberID: bob, toMemberID: alice, amount: 42.50),
        ]

        let message = SplitGroupShareDraft.inviteMessage(
            groupName: "Weekend Trip",
            memberNames: names,
            memberIDs: [alice, bob],
            balances: balances,
            groupID: groupID,
            currencyCode: currencyCode
        )

        #expect(message.contains("Weekend Trip"))
        #expect(message.contains("Alice"))
        #expect(message.contains("Bob"))
        #expect(message.contains("42.50") || message.contains("42.5"))
        #expect(message.contains(SplitGroupDeepLink.url(for: groupID).absoluteString))
    }

    @Test("summary message lists outstanding expenses")
    func summaryListsExpenses() {
        let names: [UUID: String] = [
            alice: "Alice",
            bob: "Bob",
        ]
        let groupID = UUID()
        let expenses = [
            GroupExpense(
                groupID: groupID,
                paidByMemberID: alice,
                amount: 100,
                title: "Dinner",
                date: Date(timeIntervalSince1970: 1_700_000_000)
            ),
        ]

        let message = SplitGroupShareDraft.summaryMessage(
            groupName: "Roommates",
            memberNames: names,
            memberIDs: [alice, bob],
            balances: [],
            outstandingExpenses: expenses,
            currencyCode: currencyCode
        )

        #expect(message.contains("Roommates"))
        #expect(message.contains("Dinner"))
        #expect(message.contains("All settled up") || message.contains("settled"))
    }
}

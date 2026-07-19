import Foundation
import Testing
import VittoraCore
@testable import Vittora

@Suite("Quick Add Deep Link Tests")
struct QuickAddDeepLinkTests {

    @Test("builds and parses expense, income, and transfer URLs")
    func roundTripValidTypes() {
        for destination in QuickAddDeepLink.Destination.allCases {
            let url = QuickAddDeepLink.url(for: destination)

            #expect(url.scheme == "vittora")
            #expect(url.host == "add")
            #expect(QuickAddDeepLink.isQuickAddURL(url))
            #expect(QuickAddDeepLink.destination(from: url) == destination)
        }
    }

    @Test("parses type query case-insensitively")
    func parsesCaseInsensitiveType() {
        guard let url = URL(string: "vittora://add?type=EXPENSE") else {
            Issue.record("URL should parse")
            return
        }
        #expect(QuickAddDeepLink.destination(from: url) == .expense)
    }

    @Test("unknown type returns nil so the app opens normally")
    func unknownTypeFallsBack() {
        guard let unknown = URL(string: "vittora://add?type=refund"),
              let missing = URL(string: "vittora://add") else {
            Issue.record("URLs should parse")
            return
        }
        #expect(QuickAddDeepLink.isQuickAddURL(unknown))
        #expect(QuickAddDeepLink.destination(from: unknown) == nil)
        #expect(QuickAddDeepLink.isQuickAddURL(missing))
        #expect(QuickAddDeepLink.destination(from: missing) == nil)
    }

    @Test("malformed and unrelated URLs are ignored")
    func rejectsMalformedURLs() {
        let samples = [
            "https://example.com",
            "vittora://dashboard",
            "vittora://splits",
            "vittora://",
        ]
        for sample in samples {
            guard let url = URL(string: sample) else {
                Issue.record("URL should parse: \(sample)")
                continue
            }
            #expect(QuickAddDeepLink.destination(from: url) == nil)
        }
    }
}

@Suite("AppState Quick Add Routing Tests")
@MainActor
struct AppStateQuickAddRoutingTests {

    @Test("valid add URLs queue a pending destination on the dashboard tab")
    func queuesValidQuickAdd() {
        let state = AppState(selectedTab: .settings)

        state.openFromURL(QuickAddDeepLink.url(for: .income))

        #expect(state.pendingQuickAdd == .income)
        #expect(state.selectedTab == .dashboard)
    }

    @Test("unknown add type opens the app without queuing a destination")
    func unknownTypeDoesNotQueue() {
        let state = AppState(selectedTab: .settings)
        guard let url = URL(string: "vittora://add?type=unknown") else {
            Issue.record("URL should parse")
            return
        }

        state.openFromURL(url)

        #expect(state.pendingQuickAdd == nil)
        #expect(state.selectedTab == .settings)
    }

    @Test("malformed vittora URLs do not crash or change tab")
    func malformedURLsAreIgnored() {
        let state = AppState(selectedTab: .budgets)
        guard let url = URL(string: "vittora://not-a-real-host") else {
            Issue.record("URL should parse")
            return
        }

        state.openFromURL(url)

        #expect(state.pendingQuickAdd == nil)
        #expect(state.pendingSplitGroupID == nil)
        #expect(state.selectedTab == .budgets)
    }

    @Test("pending quick add survives until cleared after unlock")
    func pendingSurvivesUntilCleared() {
        let state = AppState(isAuthenticated: false, isLocked: true)
        state.openFromURL(QuickAddDeepLink.url(for: .expense))

        #expect(state.pendingQuickAdd == QuickAddDeepLink.Destination.expense)

        state.isLocked = false
        state.isAuthenticated = true
        #expect(state.pendingQuickAdd == QuickAddDeepLink.Destination.expense)

        state.clearPendingQuickAdd()
        #expect(state.pendingQuickAdd == nil)
    }
}

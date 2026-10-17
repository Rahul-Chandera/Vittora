import Foundation
import Testing
@testable import Vittora

/// `vittora://tax` — the deep link for the tax custom product pages. On iPhone
/// Tax sits behind the More hub, so the link must queue it for the hub to push,
/// not just select a tab the compact bar maps to the hub root.
@Suite("Tax Deep Link")
@MainActor
struct TaxDeepLinkTests {

    @Test("vittora://tax selects Tax and queues it for the More hub")
    func opensTax() throws {
        let state = AppState()
        state.openFromURL(try #require(URL(string: "vittora://tax")))
        #expect(state.selectedTab == .tax)
        #expect(state.pendingOverflowDestination == .tax)
    }

    @Test("the host is case-insensitive")
    func caseInsensitive() throws {
        let state = AppState()
        state.openFromURL(try #require(URL(string: "VITTORA://TAX")))
        #expect(state.pendingOverflowDestination == .tax)
    }

    @Test("other links leave the overflow destination alone")
    func otherLinks() throws {
        let state = AppState()
        state.openFromURL(try #require(URL(string: "vittora://budget")))
        #expect(state.pendingOverflowDestination == nil)
    }
}

import Testing
@testable import Vittora

@Suite("AppState Refresh Tests")
@MainActor
struct AppStateRefreshTests {

    @Test("notifyChanged bumps only the targeted domain")
    func domainSpecificRefresh() {
        let state = AppState()

        state.notifyChanged(.categories)

        #expect(state.refreshVersion(for: .categories) == 1)
        #expect(state.refreshVersion(for: .transactions) == 0)
        #expect(state.refreshVersion(for: .accounts) == 0)
    }

    @Test("notifyChanged with multiple domains bumps each independently")
    func multiDomainRefresh() {
        let state = AppState()

        state.notifyChanged([.transactions, .accounts, .budgets])

        #expect(state.refreshVersion(for: .transactions) == 1)
        #expect(state.refreshVersion(for: .accounts) == 1)
        #expect(state.refreshVersion(for: .budgets) == 1)
        #expect(state.refreshVersion(for: .payees) == 0)
    }

    @Test("dashboardRefreshToken changes when a dashboard domain updates")
    func dashboardRefreshToken() {
        let state = AppState()
        let initial = state.dashboardRefreshToken

        state.notifyChanged(.budgets)

        #expect(state.dashboardRefreshToken != initial)
        #expect(state.hasAnyRefresh(in: [.transactions, .accounts, .budgets, .recurring]))
    }
}

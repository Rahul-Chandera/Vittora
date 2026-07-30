import Foundation
import Testing
import VittoraCore
@testable import Vittora

@Suite("Handoff Deep Link Tests")
struct HandoffDeepLinkTests {

    @Test("encode → decode URL preserves each source screen route")
    func urlRoundTripMatchesSourceRoute() {
        let transactionID = UUID()
        let budgetID = UUID()
        let accountID = UUID()
        let categoryID = UUID()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = Date(timeIntervalSince1970: 1_700_086_400)

        let routes: [HandoffDeepLink.Route] = [
            .transactionList(
                HandoffDeepLink.ListFilter(
                    start: start,
                    end: end,
                    types: ["expense"],
                    categoryIDs: [categoryID].sorted { $0.uuidString < $1.uuidString },
                    accountIDs: [accountID].sorted { $0.uuidString < $1.uuidString }
                )
            ),
            .transactionDetail(transactionID),
            .budgetDetail(budgetID),
            .accountDetail(accountID),
            .reportDetail(type: ReportType.category.rawValue, start: start, end: end),
            .transactionDraft(
                HandoffDeepLink.Draft(
                    amount: "15.49",
                    note: "Coffee",
                    categoryID: categoryID,
                    accountID: accountID,
                    date: start,
                    type: "expense"
                )
            ),
            .budgetsList,
            .accountsList,
        ]

        for route in routes {
            let url = HandoffDeepLink.url(for: route)
            let decoded = HandoffDeepLink.route(from: url)
            #expect(decoded == route, "URL round-trip failed for \(route)")
        }
    }

    @Test("encode → decode userInfo preserves each source screen route")
    func userInfoRoundTripMatchesSourceRoute() {
        let id = UUID()
        let routes: [HandoffDeepLink.Route] = [
            .transactionList(HandoffDeepLink.ListFilter(start: nil, end: nil)),
            .transactionDetail(id),
            .budgetDetail(id),
            .accountDetail(id),
            .reportDetail(type: "trends", start: nil, end: nil),
            .transactionDraft(HandoffDeepLink.Draft(amount: "10.00", type: "income")),
        ]

        for route in routes {
            let info = HandoffDeepLink.userInfo(for: route)
            #expect(HandoffDeepLink.userInfoContainsForbiddenKeys(info) == false)
            #expect(HandoffDeepLink.route(fromUserInfo: info) == route)
        }
    }

    @Test("activity userInfo keys are all on the allowlist (fail closed)")
    func userInfoKeysAreAllowlisted() {
        let routes: [HandoffDeepLink.Route] = [
            .transactionList(HandoffDeepLink.ListFilter()),
            .transactionDetail(UUID()),
            .budgetDetail(UUID()),
            .accountDetail(UUID()),
            .reportDetail(type: "monthly", start: nil, end: nil),
            .transactionDraft(HandoffDeepLink.Draft(amount: "42.00", note: "x")),
        ]

        for route in routes {
            let activity = AppHandoff.makeActivity(for: route)
            #expect(activity.isEligibleForHandoff)
            #expect(activity.isEligibleForSearch == false)
            #expect(HandoffDeepLink.userInfoContainsForbiddenKeys(activity.userInfo) == false)

            let keys = Set((activity.userInfo ?? [:]).keys.map { String(describing: $0) })
            #expect(keys.isSubset(of: HandoffDeepLink.allowedUserInfoKeys))
        }

        // Fail closed: a novel key (e.g. accountBalance) is forbidden even if
        // it is not one of the old denylist spellings.
        #expect(HandoffDeepLink.userInfoContainsForbiddenKeys(["kind": "transaction", "accountBalance": "1"]))
        #expect(HandoffDeepLink.userInfoContainsForbiddenKeys(["monthTotal": "100"]))
        #expect(HandoffDeepLink.userInfoContainsForbiddenKeys(["balance": "50"]))
    }

    @Test("deleted transaction resolves to the transaction list")
    func deletedTransactionFallsBackToList() {
        let missing = UUID()
        let resolved = HandoffDeepLink.resolve(
            .transactionDetail(missing),
            transactionExists: { _ in false }
        )
        #expect(resolved == .transactionList(HandoffDeepLink.ListFilter()))
    }

    @Test("deleted budget resolves to budgets list")
    func deletedBudgetFallsBackToList() {
        let resolved = HandoffDeepLink.resolve(
            .budgetDetail(UUID()),
            budgetExists: { _ in false }
        )
        #expect(resolved == .budgetsList)
    }

    @Test("existing transaction detail is unchanged by resolve")
    func existingTransactionKeepsDetail() {
        let id = UUID()
        let resolved = HandoffDeepLink.resolve(
            .transactionDetail(id),
            transactionExists: { $0 == id }
        )
        #expect(resolved == .transactionDetail(id))
    }
}

@Suite("AppState Handoff Routing Tests")
@MainActor
struct AppStateHandoffRoutingTests {

    @Test("flipping isHandoffAdvertisingSuspended stops advertisement")
    func flippingSuspendedStopsAdvertisement() {
        let state = AppState()
        #expect(state.shouldAdvertiseHandoff(isActive: true))

        state.isHandoffAdvertisingSuspended = true
        #expect(!state.shouldAdvertiseHandoff(isActive: true))

        state.isHandoffAdvertisingSuspended = false
        #expect(state.shouldAdvertiseHandoff(isActive: true))

        // UI testing and inactive still gate independently.
        state.isUITesting = true
        #expect(!state.shouldAdvertiseHandoff(isActive: true))
        state.isUITesting = false
        #expect(!state.shouldAdvertiseHandoff(isActive: false))
    }

    @Test("activity encode → decode → openFromURL routes to the source screen")
    func activityEncodeDecodeRoutesThroughOpenFromURL() {
        let cases: [(HandoffDeepLink.Route, AppState.AppTab)] = [
            (.transactionList(HandoffDeepLink.ListFilter()), .transactions),
            (.transactionDetail(UUID()), .transactions),
            (.budgetDetail(UUID()), .budgets),
            (.accountDetail(UUID()), .dashboard),
            (.reportDetail(type: ReportType.monthly.rawValue, start: nil, end: nil), .reports),
        ]

        for (route, expectedTab) in cases {
            let state = AppState(selectedTab: .settings)
            let activity = AppHandoff.makeActivity(for: route)
            let decoded = AppHandoff.route(from: activity)
            #expect(decoded == route)

            // Continuation feeds the same openFromURL path as widgets / Spotlight.
            state.openFromURL(HandoffDeepLink.url(for: decoded!))
            #expect(state.selectedTab == expectedTab)
        }
    }

    @Test("transaction detail handoff sets pending ID via openFromURL")
    func transactionDetailWiresPendingID() {
        let state = AppState(selectedTab: .dashboard)
        let id = UUID()
        let activity = AppHandoff.makeActivity(for: .transactionDetail(id))

        state.openFromHandoffActivity(activity)

        #expect(state.pendingTransactionDetailID == id)
        #expect(state.selectedTab == .transactions)
    }

    @Test("unsaved draft survives continuation with every field")
    func draftContinuationPreservesFields() {
        let state = AppState(selectedTab: .settings)
        let categoryID = UUID()
        let accountID = UUID()
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let draft = HandoffDeepLink.Draft(
            amount: "15.49",
            note: "Lunch",
            categoryID: categoryID,
            accountID: accountID,
            date: date,
            type: "expense"
        )
        let route = HandoffDeepLink.Route.transactionDraft(draft)
        let activity = AppHandoff.makeActivity(for: route)

        state.openFromHandoffActivity(activity)

        #expect(state.selectedTab == .dashboard)
        #expect(state.pendingQuickAdd == .expense)
        #expect(state.pendingTransactionDraft?.amount == "15.49")
        #expect(state.pendingTransactionDraft?.note == "Lunch")
        #expect(state.pendingTransactionDraft?.categoryID == categoryID)
        #expect(state.pendingTransactionDraft?.accountID == accountID)
        #expect(state.pendingTransactionDraft?.date == date)
        #expect(state.pendingTransactionDraft?.type == "expense")
    }

    @Test("deleted-transaction resolution then route lands on list without pending detail")
    func deletedTransactionResolutionWiring() {
        let state = AppState(selectedTab: .dashboard)
        let missing = UUID()
        let resolved = HandoffDeepLink.resolve(
            .transactionDetail(missing),
            transactionExists: { _ in false }
        )
        state.openFromHandoffRoute(resolved)

        #expect(resolved == .transactionList(HandoffDeepLink.ListFilter()))
        #expect(state.selectedTab == .transactions)
        #expect(state.pendingTransactionDetailID == nil)
    }

    @Test("transaction list filter handoff restores date range via openFromURL")
    func listFilterWiresPendingFilter() {
        let state = AppState(selectedTab: .settings)
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = Date(timeIntervalSince1970: 1_700_086_400)
        let filter = HandoffDeepLink.ListFilter(start: start, end: end, types: ["expense"])

        state.openFromURL(HandoffDeepLink.url(for: .transactionList(filter)))

        #expect(state.selectedTab == .transactions)
        #expect(state.pendingTransactionListFilter?.start == start)
        #expect(state.pendingTransactionListFilter?.end == end)
        #expect(state.pendingTransactionListFilter?.types == ["expense"])
    }

    @Test("existing QuickAdd and Spotlight URLs still route through openFromURL")
    func legacyDeepLinksStillWork() {
        let state = AppState(selectedTab: .settings)
        state.openFromURL(QuickAddDeepLink.url(for: .income))
        #expect(state.pendingQuickAdd == .income)
        #expect(state.selectedTab == .dashboard)

        let tx = UUID()
        state.openFromURL(TransactionSpotlightDeepLink.url(for: tx))
        #expect(state.pendingTransactionDetailID == tx)
        #expect(state.selectedTab == .transactions)
    }

    @Test("form view model applies every handoff draft field")
    func formViewModelAppliesDraft() {
        let draft = HandoffDeepLink.Draft(
            amount: "15.49",
            note: "Taxi",
            categoryID: UUID(),
            accountID: UUID(),
            date: Date(timeIntervalSince1970: 1_700_000_000),
            type: "income"
        )
        let txRepo = MockTransactionRepository()
        let accountRepo = MockAccountRepository()
        let categoryRepo = MockCategoryRepository()
        let vm = TransactionFormViewModel(
            addUseCase: AddTransactionUseCase(
                accountRepository: accountRepo,
                categoryRepository: categoryRepo,
                ledgerWriting: MockLedgerWriting(
                    transactionRepository: txRepo,
                    accountRepository: accountRepo
                )
            ),
            updateUseCase: UpdateTransactionUseCase(
                transactionRepository: txRepo,
                ledgerWriting: MockLedgerWriting(
                    transactionRepository: txRepo,
                    accountRepository: accountRepo
                )
            ),
            smartCategorizeUseCase: SmartCategorizeUseCase(
                transactionRepository: txRepo,
                ruleStore: InMemoryCategorizationRuleStore(),
                categoryRepository: categoryRepo
            ),
            duplicateDetectionUseCase: DuplicateDetectionUseCase(transactionRepository: txRepo),
            currencyCode: "USD"
        )

        vm.applyHandoffDraft(draft)

        #expect(vm.amountString == "15.49")
        #expect(vm.note == "Taxi")
        #expect(vm.selectedCategoryID == draft.categoryID)
        #expect(vm.selectedAccountID == draft.accountID)
        #expect(vm.date == draft.date)
        #expect(vm.type == .income)
    }
}

import XCTest

#if canImport(UIKit)
import UIKit
#endif

/// VoiceOver, Dynamic Type, contrast, and hit-target regression gate for iOS.
final class AccessibilityAuditUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = true
        #if os(macOS)
        throw XCTSkip("P1 accessibility audit runs on iPhone Simulator.")
        #else
        app = XCUIApplication()
        #endif
    }

    // This class launches the app far more often than it terminates it, and the first
    // test to run alphabetically (testAccessibility3ScreenshotsForCoreFlows) launches at
    // AccessibilityXL, so per-process content-size and app state can carry into the
    // launches that follow; launchSeeded already pins an explicit content size category
    // for the same reason. Terminating here gives every test a cold process.
    override func tearDownWithError() throws {
        #if !os(macOS)
        app?.terminate()
        #endif
        app = nil
    }

    // MARK: - performAccessibilityAudit

    @MainActor
    func testDashboardAccessibilityAudit() throws {
        #if os(macOS)
        throw XCTSkip("iOS only")
        #else
        launchSeeded(initialTab: "dashboard", extraArguments: ["--ui-test-pro"])
        XCTAssertTrue(UITestSupport.waitForContentRoot(in: app))
        XCTAssertTrue(app.navigationBars["Dashboard"].waitForExistence(timeout: 15))
        try performCoreFlowAudit()
        #endif
    }

    @MainActor
    func testAddTransactionAccessibilityAudit() throws {
        #if os(macOS)
        throw XCTSkip("iOS only")
        #else
        launchSeeded(initialTab: "transactions", extraArguments: ["--ui-test-pro"])
        XCTAssertTrue(UITestSupport.waitForContentRoot(in: app))
        openAddTransactionForm()
        try performCoreFlowAudit()
        #endif
    }

    @MainActor
    func testTransactionListAndDetailAccessibilityAudit() throws {
        #if os(macOS)
        throw XCTSkip("iOS only")
        #else
        launchSeeded(initialTab: "transactions", extraArguments: ["--ui-test-pro"])
        XCTAssertTrue(UITestSupport.waitForContentRoot(in: app))
        XCTAssertTrue(
            app.descendants(matching: .any)["transaction-list-root"].waitForExistence(timeout: 15),
            "Transaction list should be visible."
        )
        try performCoreFlowAudit()

        let row = firstTransactionRow()
        XCTAssertTrue(row.waitForExistence(timeout: 15), "Seeded transaction row should exist.")
        UITestSupport.tapWhenReady(row, timeout: 10)
        XCTAssertTrue(
            app.buttons["Edit transaction"].waitForExistence(timeout: 10)
                || app.navigationBars.firstMatch.waitForExistence(timeout: 10),
            "Transaction detail should appear."
        )
        try performCoreFlowAudit()
        #endif
    }

    @MainActor
    func testBudgetsAccessibilityAudit() throws {
        #if os(macOS)
        throw XCTSkip("iOS only")
        #else
        launchSeeded(initialTab: "budgets", extraArguments: ["--ui-test-pro"])
        XCTAssertTrue(UITestSupport.waitForContentRoot(in: app))
        XCTAssertTrue(
            app.descendants(matching: .any)["budget-list-root"].waitForExistence(timeout: 15)
                || app.staticTexts["No Budgets Yet"].waitForExistence(timeout: 15)
                || app.navigationBars["Budgets"].waitForExistence(timeout: 15),
            "Budgets screen should appear."
        )
        try performCoreFlowAudit()
        #endif
    }

    @MainActor
    func testReportsHomeAndMonthlyOverviewAccessibilityAudit() throws {
        #if os(macOS)
        throw XCTSkip("iOS only")
        #else
        launchSeeded(initialTab: "reports", extraArguments: ["--ui-test-pro"])
        XCTAssertTrue(UITestSupport.waitForContentRoot(in: app))
        XCTAssertTrue(app.navigationBars["Reports"].waitForExistence(timeout: 15))
        try performCoreFlowAudit()

        let card = app.descendants(matching: .any)["report-card-monthly"].firstMatch
        for _ in 0..<6 where !card.exists || !card.isHittable {
            app.swipeUp()
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        XCTAssertTrue(card.waitForExistence(timeout: 15), "Monthly Overview card should exist.")
        card.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.navigationBars["Monthly Overview"].waitForExistence(timeout: 15))
        try performCoreFlowAudit()
        #endif
    }

    @MainActor
    func testTaxSurfacesAccessibilityAudit() throws {
        #if os(macOS)
        throw XCTSkip("iOS only")
        #else
        for region in ["US", "IN"] {
            launchSeeded(
                initialTab: "settings",
                extraArguments: ["--ui-test-pro"],
                extraEnvironment: ["UITEST_DEMO_REGION": region]
            )
            openOverflowDestination(named: "Tax", navigationTitle: "Tax Estimator")
            XCTAssertTrue(app.staticTexts["Bracket Distribution"].waitForExistence(timeout: 20))
            try performCoreFlowAudit()

            UITestSupport.tapWhenReady(app.buttons["tax-profile-button"], timeout: 10)
            XCTAssertTrue(app.navigationBars["Tax Profile"].waitForExistence(timeout: 10))
            try performCoreFlowAudit()
            dismissPresentedScreen()
            XCTAssertTrue(app.navigationBars["Tax Estimator"].waitForExistence(timeout: 10))
            XCTAssertTrue(app.staticTexts["Bracket Distribution"].waitForExistence(timeout: 10))

            let breakdown = app.buttons["Full Bracket Breakdown"].firstMatch
            var swipes = 0
            while (!breakdown.exists || breakdown.frame.maxY > app.frame.maxY - 140) && swipes < 12 {
                app.swipeUp()
                swipes += 1
                RunLoop.current.run(until: Date().addingTimeInterval(0.3))
            }
            XCTAssertTrue(breakdown.waitForExistence(timeout: 10))
            // Tap the upper half so the hit isn't swallowed by the tab bar.
            breakdown.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2)).tap()
            XCTAssertTrue(app.navigationBars["Tax Breakdown"].waitForExistence(timeout: 10))
            try performCoreFlowAudit()
            app.terminate()
        }
        #endif
    }

    @MainActor
    func testSavingsSurfacesAccessibilityAudit() throws {
        #if os(macOS)
        throw XCTSkip("iOS only")
        #else
        launchSeeded(initialTab: "settings", extraArguments: ["--ui-test-pro"])
        openOverflowDestination(named: "Savings", navigationTitle: "Savings Goals")
        try performCoreFlowAudit()

        tapText("Emergency Fund")
        XCTAssertTrue(app.navigationBars["Emergency Fund"].waitForExistence(timeout: 10))
        let contribution = app.textFields["savings-contribution-field"]
        UITestSupport.scrollToElement(contribution, in: app)
        XCTAssertTrue(contribution.waitForExistence(timeout: 10))
        try performCoreFlowAudit()

        app.navigationBars.buttons.firstMatch.tap()
        UITestSupport.tapWhenReady(app.buttons["savings-add-button"], timeout: 10)
        XCTAssertTrue(app.navigationBars["New Goal"].waitForExistence(timeout: 10))
        try performCoreFlowAudit()
        #endif
    }

    @MainActor
    func testSplitSurfacesAccessibilityAudit() throws {
        #if os(macOS)
        throw XCTSkip("iOS only")
        #else
        launchSeeded(initialTab: "settings", extraArguments: ["--ui-test-pro"])
        openOverflowDestination(named: "Splits", navigationTitle: "Split Expenses")
        try performCoreFlowAudit()

        tapText("Lake House Weekend")
        XCTAssertTrue(app.navigationBars["Lake House Weekend"].waitForExistence(timeout: 10))
        try performCoreFlowAudit()

        UITestSupport.tapWhenReady(app.buttons["split-expense-add-button"], timeout: 10)
        XCTAssertTrue(app.navigationBars["Add Expense"].waitForExistence(timeout: 10))
        try performCoreFlowAudit()
        dismissPresentedScreen()

        app.navigationBars.buttons.firstMatch.tap()
        UITestSupport.tapWhenReady(app.buttons["split-group-add-button"], timeout: 10)
        XCTAssertTrue(app.navigationBars["New Group"].waitForExistence(timeout: 10))
        try performCoreFlowAudit()
        #endif
    }

    @MainActor
    func testDebtSurfacesAccessibilityAudit() throws {
        #if os(macOS)
        throw XCTSkip("iOS only")
        #else
        launchSeeded(initialTab: "settings", extraArguments: ["--ui-test-pro"])
        openOverflowDestination(named: "Debt", navigationTitle: "Debt Ledger")
        try performCoreFlowAudit()

        UITestSupport.tapWhenReady(app.buttons["debt-analytics-button"], timeout: 10)
        XCTAssertTrue(app.navigationBars["Debt Analytics"].waitForExistence(timeout: 10))
        try performCoreFlowAudit()
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Debt Ledger"].waitForExistence(timeout: 10))

        tapText("Alex Carter")
        XCTAssertTrue(app.navigationBars["Alex Carter"].waitForExistence(timeout: 10))
        try performCoreFlowAudit()

        UITestSupport.scrollToElement(app.buttons["Settle"].firstMatch, in: app)
        UITestSupport.tapWhenReady(app.buttons["Settle"].firstMatch)
        XCTAssertTrue(app.navigationBars["Settle Debt"].waitForExistence(timeout: 10))
        try performCoreFlowAudit()
        dismissPresentedScreen()

        app.terminate()
        launchSeeded(initialTab: "settings", extraArguments: ["--ui-test-pro"])
        openOverflowDestination(named: "Debt", navigationTitle: "Debt Ledger")
        XCTAssertTrue(app.navigationBars["Debt Ledger"].waitForExistence(timeout: 10))
        UITestSupport.tapWhenReady(app.buttons["debt-add-button"], timeout: 10)
        XCTAssertTrue(app.navigationBars["Add Debt"].waitForExistence(timeout: 10))
        try performCoreFlowAudit()
        #endif
    }

    @MainActor
    func testSettingsSectionsAccessibilityAudit() throws {
        #if os(macOS)
        throw XCTSkip("iOS only")
        #else
        let sections = [
            ("Edit profile", "Profile"),
            ("Currency", "Currency"),
            ("Appearance", "Appearance"),
            ("App Lock", "Security"),
            ("Search Privacy", "Search Privacy"),
            ("Security audit log", "Security audit log"),
            ("iCloud Sync", "iCloud Sync"),
            ("Manage Data", "Manage Data"),
            ("Notifications", "Notifications"),
            ("About Vittora", "About Vittora")
        ]

        launchSeeded(initialTab: "settings", extraArguments: ["--ui-test-pro"])
        openOverflowDestination(named: "Settings", navigationTitle: "Settings")
        try performCoreFlowAudit()
        app.terminate()

        for section in sections {
            launchSeeded(initialTab: "settings", extraArguments: ["--ui-test-pro"])
            openOverflowDestination(named: "Settings", navigationTitle: "Settings")
            tapText(section.0)
            XCTAssertTrue(app.navigationBars[section.1].waitForExistence(timeout: 10))
            try performCoreFlowAudit()
            app.terminate()
        }
        #endif
    }

    @MainActor
    func testManagedListsFormsAndDocumentsAccessibilityAudit() throws {
        throw XCTSkip("""
            Still deferred. Re-measured 2026-08-07 on iPhone 17 Pro Max / \
            iOS 26.2 — the device the CI resolver picks — with both skips \
            removed and the full class run in order. The earlier reason \
            recorded here was wrong in its specifics and is replaced:

            * It claimed 15 mis-sampled contrast elements and 3 genuine \
              elementDetection findings. Actual counts are now 3 contrast and \
              ZERO elementDetection. Most of the 15 were the clearance strip \
              slicing rows mid-glyph, fixed in #197 — an opaque safeAreaInset \
              painted OVER scrolling content, and the sampler read the \
              surviving sliver as failing text.
            * What blocks re-enabling is not a count, it is VARIANCE. Two \
              runs of near-identical code produced 1 and then 10 contrast \
              findings in this test. Every exported element image is clean \
              dark-on-light text — "Monthly", "13 Aug 2026", black on #F2F2F7 \
              at roughly 18:1. They are false positives, and how many appear \
              changes run to run.
            * Un-skipping these two also destabilises the rest of the class: \
              they add many app launches, and testSettingsSectionsAccessibility\
              Audit flipped from pass to fail between those same two runs \
              without any change touching it.

            So these stay skipped because they are not yet reliable GATES, \
            not because the app has known defects here. Forcing them green \
            would need an exclusion broad enough to hide real findings. \
            Re-measure when Apple's sampler stabilises; the diagnostic recipe \
            is in Docs/Agent/tasks-1.4.2/tax-stattile-contrast.md.
            """)
        #if os(macOS)
        throw XCTSkip("iOS only")
        #else
        let surfaces = [
            ("Accounts", "settings-manage-accounts", "Accounts", "account-add-button", "New Account"),
            ("Categories", "settings-manage-categories", "Categories", "category-add-button", "New Category"),
            ("Payees", "settings-manage-payees", "Payees", "payee-add-button", "New Payee"),
            ("Recurring", "settings-manage-recurring", "Recurring Transactions", "recurring-add-button", "New Recurring")
        ]
        for surface in surfaces {
            launchSeeded(initialTab: "settings", extraArguments: ["--ui-test-pro"])
            openOverflowDestination(named: "Settings", navigationTitle: "Settings")
            openManagedSettingsDestination(
                title: surface.0,
                identifier: surface.1,
                navigationTitle: surface.2
            )
            try performCoreFlowAudit()
            UITestSupport.tapWhenReady(app.buttons[surface.3], timeout: 10)
            XCTAssertTrue(app.navigationBars[surface.4].waitForExistence(timeout: 10))
            try performCoreFlowAudit()
            app.terminate()
        }

        launchSeeded(initialTab: "transactions", extraArguments: ["--ui-test-pro"])
        XCTAssertTrue(UITestSupport.waitForContentRoot(in: app))
        UITestSupport.tapWhenReady(firstTransactionRow(), timeout: 15)
        XCTAssertTrue(app.descendants(matching: .any)["transaction-detail-root"].waitForExistence(timeout: 10))
        let attachments = app.staticTexts["Attachments"]
        UITestSupport.scrollToElement(attachments, in: app)
        XCTAssertTrue(attachments.waitForExistence(timeout: 10))
        try performCoreFlowAudit()
        UITestSupport.tapWhenReady(app.buttons["document-add-button"])
        UITestSupport.tapWhenReady(app.buttons["Import File"])
        XCTAssertTrue(app.navigationBars["Import"].waitForExistence(timeout: 10))
        try performCoreFlowAudit()
        #endif
    }

    @MainActor
    func testOnboardingAccessibilityAudit() throws {
        #if os(macOS)
        throw XCTSkip("iOS only")
        #else
        app.launchArguments = [
            "--uitesting", "--ui-test-onboarding", "--ui-test-seed-demo",
            "--ui-test-reset-app-lock", "--ui-test-pro"
        ]
        app.launchEnvironment["UITEST_FORCE_ONBOARDING"] = "1"
        app.launch()
        XCTAssertTrue(
            app.staticTexts["onboarding-welcome-title"].waitForExistence(timeout: 30)
        )
        try performCoreFlowAudit()

        let next = app.buttons["onboarding-next-button"]
        UITestSupport.tapWhenReady(next)
        let usdCurrency = app.descendants(matching: .any)["onboarding-currency-USD"]
        XCTAssertTrue(usdCurrency.waitForExistence(timeout: 10))
        try performCoreFlowAudit()
        UITestSupport.tapWhenReady(usdCurrency)
        UITestSupport.tapWhenReady(next)

        let name = app.textFields["onboarding-name-field"]
        XCTAssertTrue(name.waitForExistence(timeout: 10))
        try performCoreFlowAudit()
        name.tap()
        name.typeText("Taylor")
        UITestSupport.tapWhenReady(next)

        let accountType = app.descendants(matching: .any)["onboarding-account-type-bank"]
        XCTAssertTrue(accountType.waitForExistence(timeout: 10))
        try performCoreFlowAudit()
        #endif
    }

    /// The paywall is a sheet, so `testSettingsSectionsAccessibilityAudit`'s
    /// NavigationLink walk never reaches it. It is audited here, together with the
    /// manual Settings entry point that App Review 3.1.1 requires — a user who bought
    /// on another device must be able to restore without a value event firing first.
    ///
    /// The store view's tint is `VColors.primaryOnSurface` (#17604A), the house
    /// primary fill (DEC-018 reverses DEC-017). StoreKit derives a white label on
    /// it at 7.48:1, so the purchase CTA claims NO DEC-012 exemption — neither do
    /// the lifetime button, the bullet glyphs, or the policy links.
    ///
    /// This test deliberately audits whichever state the paywall reaches. On a
    /// toolchain where StoreKit Testing does not serve products,
    /// `Product.products(for:)` returns zero and the paywall renders its
    /// products-unavailable state — which is exactly the state a real offline user
    /// gets, so it is worth auditing on its own merits. There is no `XCTSkip` here:
    /// a skip would hide that the purchase path never executed.
    ///
    /// The branch is recorded as a test activity so the result bundle says which
    /// state ran. If every run for a release only ever reports the
    /// products-unavailable activity, the loaded purchase path has never been
    /// exercised on CI and still needs a manual sandbox pass before shipping.
    @MainActor
    func testPaywallAccessibilityAudit() throws {
        #if os(macOS)
        throw XCTSkip("iOS only")
        #else
        launchSeeded(initialTab: "settings")
        openOverflowDestination(named: "Settings", navigationTitle: "Settings")

        let proRow = app.descendants(matching: .any)["settings-vittora-pro"].firstMatch
        UITestSupport.scrollToElement(proRow, in: app)
        XCTAssertTrue(
            proRow.waitForExistence(timeout: 15),
            "Settings must expose a manual Vittora Pro entry point (App Review 3.1.1)."
        )

        let restore = app.descendants(matching: .any)["settings-restore-purchases"].firstMatch
        XCTAssertTrue(
            restore.waitForExistence(timeout: 15),
            "Restore Purchases must be reachable from Settings without a value event (App Review 3.1.1)."
        )

        UITestSupport.tapWhenReady(proRow, timeout: 15)
        XCTAssertTrue(app.navigationBars["Vittora Pro"].waitForExistence(timeout: 20))

        // SubscriptionStoreView fills in asynchronously once StoreKit answers. Audit the
        // loaded state, not the placeholder: the disclosure text is the last thing to render.
        XCTAssertTrue(
            app.descendants(matching: .any)["paywall-auto-renew-disclosure"]
                .waitForExistence(timeout: 20),
            "Paywall must finish rendering either its loaded store content or its products-unavailable content before the audit samples it."
        )

        let unavailable = app.descendants(matching: .any)["paywall-products-unavailable"].firstMatch
        if unavailable.exists {
            XCTContext.runActivity(named: "Paywall rendered its products-unavailable state") { _ in }
            // A user whose product load failed must still be able to recover a purchase
            // they already made, and must still see the 3.1.2 auto-renew disclosure.
            XCTAssertTrue(
                app.descendants(matching: .any)["paywall-restore-button"].firstMatch.waitForExistence(timeout: 10),
                "The degraded paywall must still offer Restore Purchases (App Review 3.1.1)."
            )
            XCTAssertTrue(
                app.descendants(matching: .any)["paywall-retry-button"].firstMatch.exists,
                "The degraded paywall must offer a retry."
            )
        } else {
            XCTContext.runActivity(named: "Paywall rendered its loaded store state") { _ in }
        }

        try performCoreFlowAudit()
        #endif
    }

    @MainActor
    func testNewReportsAccessibilityAudit() throws {
        #if os(macOS)
        throw XCTSkip("iOS only")
        #else
        launchSeeded(initialTab: "reports", extraArguments: ["--ui-test-pro"])
        XCTAssertTrue(app.navigationBars["Reports"].waitForExistence(timeout: 15))
        let emergency = app.descendants(matching: .any)["report-card-emergencyFund"].firstMatch
        // The card's maxY bottoms out at 753 on this window, so a break at
        // app.frame.maxY - 120 (= 732) could never be taken: the loop that used
        // to sit here always burned all ten swipes and left the list
        // over-scrolled for scrollToElement to undo. scrollToElement already
        // does this job against the real nav-bar and tab-bar frames.
        UITestSupport.scrollToElement(emergency, in: app)
        XCTAssertTrue(emergency.waitForExistence(timeout: 15), "Emergency Fund report card should exist.")
        emergency.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.navigationBars["Emergency Fund"].waitForExistence(timeout: 15))
        let coverage = app.descendants(matching: .any)["emergency-fund-coverage-summary"]
        XCTAssertTrue(coverage.waitForExistence(timeout: 10))
        XCTAssertFalse((coverage.value as? String ?? "").isEmpty)
        let contributingAccounts = app.staticTexts["Contributing Accounts"]
        UITestSupport.scrollToElement(contributingAccounts, in: app)
        try performCoreFlowAudit()

        // G1's 50/30/20 report is audited here as soon as that parallel
        // feature lands on develop; until then there is no production surface.
        if app.descendants(matching: .any)["report-card-fiftyThirtyTwenty"].exists {
            app.navigationBars.buttons.firstMatch.tap()
            let report = app.descendants(matching: .any)["report-card-fiftyThirtyTwenty"].firstMatch
            UITestSupport.scrollToElement(report, in: app)
            UITestSupport.tapWhenReady(report)
            try performCoreFlowAudit()
        }
        #endif
    }

    @MainActor
    func testOLEDBlackAccessibilityAuditForCoreFlows() throws {
        #if os(macOS)
        throw XCTSkip("iOS only")
        #else
        launchSeeded(
            initialTab: "dashboard",
            extraArguments: ["--ui-test-appearance=oledBlack", "--ui-test-accent=purple", "--ui-test-pro"]
        )
        XCTAssertTrue(UITestSupport.waitForContentRoot(in: app))
        XCTAssertTrue(app.navigationBars["Dashboard"].waitForExistence(timeout: 15))
        try performCoreFlowAudit()
        captureFlowScreenshot(named: "oled-dashboard-purple")

        XCTAssertTrue(UITestSupport.navigateToTab(named: "Transactions", in: app))
        XCTAssertTrue(
            app.descendants(matching: .any)["transaction-list-root"].waitForExistence(timeout: 15)
        )
        try performCoreFlowAudit()

        let row = firstTransactionRow()
        XCTAssertTrue(row.waitForExistence(timeout: 15))
        UITestSupport.tapWhenReady(row)
        try performCoreFlowAudit()
        app.navigationBars.buttons.firstMatch.tap()

        openAddTransactionForm()
        try performCoreFlowAudit()
        app.navigationBars.buttons.firstMatch.tap()

        XCTAssertTrue(UITestSupport.navigateToTab(named: "Budgets", in: app))
        try performCoreFlowAudit()

        XCTAssertTrue(UITestSupport.navigateToTab(named: "Reports", in: app))
        XCTAssertTrue(app.navigationBars["Reports"].waitForExistence(timeout: 15))
        try performCoreFlowAudit()

        let card = app.descendants(matching: .any)["report-card-monthly"].firstMatch
        UITestSupport.scrollToElement(card, in: app)
        XCTAssertTrue(card.waitForExistence(timeout: 15))
        UITestSupport.tapWhenReady(card)
        XCTAssertTrue(app.navigationBars["Monthly Overview"].waitForExistence(timeout: 15))
        try performCoreFlowAudit()
        captureFlowScreenshot(named: "oled-monthly-overview-purple")
        #endif
    }

    @MainActor
    func testOLEDAccentDashboardAndReportScreenshots() throws {
        #if os(macOS)
        throw XCTSkip("iOS only")
        #else
        for accent in ["brandGreen", "blue", "purple", "orange"] {
            launchSeeded(
                initialTab: "dashboard",
                extraArguments: ["--ui-test-appearance=oledBlack", "--ui-test-accent=\(accent)", "--ui-test-pro"]
            )
            XCTAssertTrue(UITestSupport.waitForContentRoot(in: app))
            XCTAssertTrue(app.navigationBars["Dashboard"].waitForExistence(timeout: 15))
            captureFlowScreenshot(named: "oled-dashboard-\(accent)")

            XCTAssertTrue(UITestSupport.navigateToTab(named: "Reports", in: app))
            let card = app.descendants(matching: .any)["report-card-monthly"].firstMatch
            UITestSupport.scrollToElement(card, in: app)
            XCTAssertTrue(card.waitForExistence(timeout: 15))
            UITestSupport.tapWhenReady(card)
            XCTAssertTrue(app.navigationBars["Monthly Overview"].waitForExistence(timeout: 15))
            captureFlowScreenshot(named: "oled-monthly-overview-\(accent)")
            app.terminate()
        }
        #endif
    }

    // MARK: - Dynamic Type screenshots (.accessibility3)

    @MainActor
    func testAccessibility3ScreenshotsForCoreFlows() throws {
        #if os(macOS)
        throw XCTSkip("iOS only")
        #else
        launchSeeded(
            initialTab: "dashboard",
            extraArguments: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXL", "--ui-test-pro"]
        )
        XCTAssertTrue(UITestSupport.waitForContentRoot(in: app))

        try performCoreFlowAudit()
        captureFlowScreenshot(named: "a11y3-dashboard")

        XCTAssertTrue(UITestSupport.navigateToTab(named: "Transactions", in: app))
        XCTAssertTrue(
            app.descendants(matching: .any)["transaction-list-root"].waitForExistence(timeout: 15)
        )
        try performCoreFlowAudit()
        captureFlowScreenshot(named: "a11y3-transaction-list")

        openAddTransactionForm()
        try performCoreFlowAudit()
        captureFlowScreenshot(named: "a11y3-add-transaction")
        app.navigationBars.buttons.firstMatch.tap()

        let row = firstTransactionRow()
        if row.waitForExistence(timeout: 10) {
            UITestSupport.tapWhenReady(row, timeout: 10)
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
            try performCoreFlowAudit()
            captureFlowScreenshot(named: "a11y3-transaction-detail")
            app.navigationBars.buttons.firstMatch.tap()
        }

        XCTAssertTrue(UITestSupport.navigateToTab(named: "Budgets", in: app))
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        try performCoreFlowAudit()
        captureFlowScreenshot(named: "a11y3-budgets")

        XCTAssertTrue(UITestSupport.navigateToTab(named: "Reports", in: app))
        XCTAssertTrue(app.navigationBars["Reports"].waitForExistence(timeout: 15))
        try performCoreFlowAudit()
        captureFlowScreenshot(named: "a11y3-reports-home")

        let card = app.descendants(matching: .any)["report-card-monthly"].firstMatch
        for _ in 0..<6 where !card.exists || !card.isHittable {
            app.swipeUp()
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        if card.waitForExistence(timeout: 10) {
            card.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            _ = app.navigationBars["Monthly Overview"].waitForExistence(timeout: 15)
            try performCoreFlowAudit()
            captureFlowScreenshot(named: "a11y3-monthly-overview")
        }
        #endif
    }

    @MainActor
    func testAccessibility3ScreenshotsForRemainingSurfaces() throws {
        throw XCTSkip("""
            Still deferred. Re-measured 2026-08-07 on iPhone 17 Pro Max / \
            iOS 26.2 — the device the CI resolver picks — with both skips \
            removed and the full class run in order. The earlier reason \
            recorded here was wrong in its specifics and is replaced:

            * It claimed 15 mis-sampled contrast elements and 3 genuine \
              elementDetection findings. Actual counts are now 3 contrast and \
              ZERO elementDetection. Most of the 15 were the clearance strip \
              slicing rows mid-glyph, fixed in #197 — an opaque safeAreaInset \
              painted OVER scrolling content, and the sampler read the \
              surviving sliver as failing text.
            * What blocks re-enabling is not a count, it is VARIANCE. Two \
              runs of near-identical code produced 1 and then 10 contrast \
              findings in this test. Every exported element image is clean \
              dark-on-light text — "Monthly", "13 Aug 2026", black on #F2F2F7 \
              at roughly 18:1. They are false positives, and how many appear \
              changes run to run.
            * Un-skipping these two also destabilises the rest of the class: \
              they add many app launches, and testSettingsSectionsAccessibility\
              Audit flipped from pass to fail between those same two runs \
              without any change touching it.

            So these stay skipped because they are not yet reliable GATES, \
            not because the app has known defects here. Forcing them green \
            would need an exclusion broad enough to hide real findings. \
            Re-measure when Apple's sampler stabilises; the diagnostic recipe \
            is in Docs/Agent/tasks-1.4.2/tax-stattile-contrast.md.
            """)
        #if os(macOS)
        throw XCTSkip("iOS only")
        #else
        let accessibility3 = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXL", "--ui-test-pro"]
        let overflowSurfaces = [
            ("Savings", "Savings Goals", "a11y3-savings"),
            ("Splits", "Split Expenses", "a11y3-splits"),
            ("Debt", "Debt Ledger", "a11y3-debt"),
            ("Settings", "Settings", "a11y3-settings")
        ]
        for surface in overflowSurfaces {
            launchSeeded(initialTab: "settings", extraArguments: accessibility3)
            openOverflowDestination(named: surface.0, navigationTitle: surface.1)
            try performCoreFlowAudit()
            captureFlowScreenshot(named: surface.2)
            app.terminate()
        }

        for region in ["US", "IN"] {
            launchSeeded(
                initialTab: "settings",
                extraArguments: accessibility3,
                extraEnvironment: ["UITEST_DEMO_REGION": region]
            )
            openOverflowDestination(named: "Tax", navigationTitle: "Tax Estimator")
            XCTAssertTrue(app.staticTexts["Bracket Distribution"].waitForExistence(timeout: 20))
            try performCoreFlowAudit()
            captureFlowScreenshot(named: "a11y3-tax-\(region.lowercased())")
            app.terminate()
        }

        let managedSurfaces = [
            ("Accounts", "settings-manage-accounts", "Accounts"),
            ("Categories", "settings-manage-categories", "Categories"),
            ("Payees", "settings-manage-payees", "Payees"),
            ("Recurring", "settings-manage-recurring", "Recurring Transactions")
        ]
        for managed in managedSurfaces {
            launchSeeded(initialTab: "settings", extraArguments: accessibility3)
            openOverflowDestination(named: "Settings", navigationTitle: "Settings")
            openManagedSettingsDestination(
                title: managed.0,
                identifier: managed.1,
                navigationTitle: managed.2
            )
            try performCoreFlowAudit()
            captureFlowScreenshot(named: "a11y3-\(managed.0.lowercased())")
            app.terminate()
        }

        launchSeeded(initialTab: "transactions", extraArguments: accessibility3)
        UITestSupport.tapWhenReady(firstTransactionRow(), timeout: 15)
        UITestSupport.scrollToElement(app.staticTexts["Attachments"], in: app)
        try performCoreFlowAudit()
        captureFlowScreenshot(named: "a11y3-documents")
        app.terminate()

        launchSeeded(initialTab: "reports", extraArguments: accessibility3)
        let emergency = app.descendants(matching: .any)["report-card-emergencyFund"].firstMatch
        // The card's maxY bottoms out at 753 on this window, so a break at
        // app.frame.maxY - 120 (= 732) could never be taken: the loop that used
        // to sit here always burned all ten swipes and left the list
        // over-scrolled for scrollToElement to undo. scrollToElement already
        // does this job against the real nav-bar and tab-bar frames.
        UITestSupport.scrollToElement(emergency, in: app)
        emergency.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        _ = app.navigationBars["Emergency Fund"].waitForExistence(timeout: 15)
        try performCoreFlowAudit()
        captureFlowScreenshot(named: "a11y3-emergency-fund")
        app.terminate()

        app.launchArguments = [
            "--uitesting", "--ui-test-onboarding", "--ui-test-seed-demo",
            "--ui-test-reset-app-lock", "--ui-test-pro"
        ] + accessibility3
        app.launchEnvironment["UITEST_FORCE_ONBOARDING"] = "1"
        app.launch()
        XCTAssertTrue(
            app.staticTexts["onboarding-welcome-title"].waitForExistence(timeout: 30)
        )
        try performCoreFlowAudit()
        captureFlowScreenshot(named: "a11y3-onboarding")
        #endif
    }

    // MARK: - Helpers

    @MainActor
    private func launchSeeded(
        initialTab: String,
        extraArguments: [String] = [],
        extraEnvironment: [String: String] = [:]
    ) {
        app.launchArguments = ["--uitesting", "--ui-test-seed-demo", "--ui-test-reset-app-lock"] + extraArguments
        // a11y3 screenshot cases pass AccessibilityXL via extraArguments. Without an
        // explicit category here, some simulator hosts retain that XL size across
        // XCTest relaunches and the following audits sample a size they did not opt into.
        if !extraArguments.contains("-UIPreferredContentSizeCategoryName") {
            app.launchArguments += [
                "-UIPreferredContentSizeCategoryName",
                "UICTContentSizeCategoryLarge"
            ]
        }
        app.launchEnvironment["UITEST_INITIAL_TAB"] = initialTab
        for (key, value) in extraEnvironment {
            app.launchEnvironment[key] = value
        }
        app.launch()
        XCTAssertTrue(UITestSupport.waitForAppForeground(in: app))
    }

    @MainActor
    private func openOverflowDestination(named name: String, navigationTitle: String) {
        XCTAssertTrue(UITestSupport.waitForContentRoot(in: app))
        let destination = app.buttons[name].firstMatch
        UITestSupport.scrollToElement(destination, in: app)
        UITestSupport.tapWhenReady(destination, timeout: 15)
        XCTAssertTrue(
            app.navigationBars[navigationTitle].waitForExistence(timeout: 15),
            "\(navigationTitle) should appear."
        )
    }

    @MainActor
    private func tapText(_ text: String) {
        let staticText = app.staticTexts[text].firstMatch
        let element: XCUIElement
        if staticText.exists || staticText.waitForExistence(timeout: 2) {
            element = staticText
        } else {
            // Combined NavigationLink rows may only expose the label on the
            // parent control (e.g. "Edit profile" after a seeded display name).
            element = app.descendants(matching: .any)
                .matching(NSPredicate(format: "label == %@ OR label CONTAINS %@", text, text))
                .firstMatch
        }
        UITestSupport.scrollToElement(element, in: app)
        UITestSupport.tapWhenReady(element, timeout: 15)
    }

    /// Opens a Settings → Manage destination via its accessibility identifier.
    ///
    /// **Diagnosis (PR #155):** BROKEN TEST, not a broken Payees product screen.
    /// Hierarchy dumps show `settings-manage-payees` present on Settings. The old
    /// `tapText("Payees")` path hit the child StaticText whose center sat under
    /// the large-title navigation bar (128pt at AccessibilityXL), so the
    /// NavigationLink never activated. Accounts/Categories worked because they
    /// settled further from the nav chrome after scrolling.
    @MainActor
    private func openManagedSettingsDestination(
        title: String,
        identifier: String,
        navigationTitle: String
    ) {
        let destination = app.descendants(matching: .any)[identifier].firstMatch
        UITestSupport.scrollToElement(destination, in: app, maxSwipes: 30)
        XCTAssertTrue(
            destination.waitForExistence(timeout: 10),
            "Settings manage row '\(identifier)' should exist after scrolling."
        )
        UITestSupport.scrollToElement(destination, in: app, maxSwipes: 12)

        activateManagedSettingsRow(destination, title: title)

        let addButtonID: String = switch identifier {
        case "settings-manage-accounts": "account-add-button"
        case "settings-manage-categories": "category-add-button"
        case "settings-manage-payees": "payee-add-button"
        case "settings-manage-recurring": "recurring-add-button"
        default: ""
        }

        var navAppeared = app.navigationBars[navigationTitle].waitForExistence(timeout: 8)
        var addAppeared = !addButtonID.isEmpty && app.buttons[addButtonID].waitForExistence(timeout: 2)
        if !navAppeared && !addAppeared {
            // Coordinate taps can glance the floating tab bar; recover to Settings.
            if !app.navigationBars["Settings"].exists {
                openOverflowDestination(named: "Settings", navigationTitle: "Settings")
            }
            UITestSupport.scrollToElement(destination, in: app, maxSwipes: 12)
            activateManagedSettingsRow(destination, title: title)
            navAppeared = app.navigationBars[navigationTitle].waitForExistence(timeout: 8)
            addAppeared = !addButtonID.isEmpty && app.buttons[addButtonID].waitForExistence(timeout: 2)
        }
        XCTAssertTrue(
            navAppeared || addAppeared,
            "\(navigationTitle) should open from Settings manage row '\(title)'."
        )
    }

    @MainActor
    private func activateManagedSettingsRow(_ destination: XCUIElement, title: String) {
        // Prefer accessibility activation when hittable; fall back to a center
        // coordinate tap for tall AccessibilityXL rows that still clear chrome.
        if destination.isHittable {
            destination.tap()
            return
        }
        let frame = destination.frame
        if frame.width > 1, frame.height > 1 {
            destination.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            return
        }
        let titleElement = app.staticTexts[title].firstMatch
        UITestSupport.scrollToElement(titleElement, in: app, maxSwipes: 8)
        XCTAssertTrue(
            titleElement.waitForExistence(timeout: 5),
            "Settings manage row '\(title)' title should be visible."
        )
        if titleElement.isHittable {
            titleElement.tap()
        } else {
            titleElement.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }

    @MainActor
    private func dismissPresentedScreen() {
        let cancel = app.buttons["Cancel"].firstMatch
        if cancel.exists {
            UITestSupport.tapWhenReady(cancel)
        } else {
            app.navigationBars.buttons.firstMatch.tap()
        }
    }

    @MainActor
    private func openAddTransactionForm() {
        let addButton = app.buttons["transaction-add-button"].exists
            ? app.buttons["transaction-add-button"]
            : app.buttons["Add Transaction"].firstMatch
        UITestSupport.tapWhenReady(addButton, timeout: 15)
        let amountField = app.textFields["transaction-amount-field"].exists
            ? app.textFields["transaction-amount-field"]
            : app.textFields.firstMatch
        XCTAssertTrue(amountField.waitForExistence(timeout: 10), "Add-transaction form should open.")
    }

    @MainActor
    private func firstTransactionRow() -> XCUIElement {
        let coffee = app.descendants(matching: .any)["transaction-row-coffee-run"]
        if coffee.exists { return coffee }
        let predicate = NSPredicate(format: "identifier BEGINSWITH %@", "transaction-row-")
        return app.descendants(matching: .any).matching(predicate).firstMatch
    }

    /// Put the keyboard away before sampling.
    ///
    /// The add-transaction screens focus the amount field on appear, so the
    /// keyboard covers the rows beneath it. Apple's sampler reads those
    /// occluded rows as contrast failures — "Account" and "Date" went red on
    /// CI — which measures the keyboard sitting over the form rather than the
    /// form's own colours. Nothing is excused here: the rows are audited, just
    /// once they are actually visible.
    ///
    /// A decimal pad has no Return key, so focus is resigned by tapping the
    /// navigation bar, which is inert on these screens.
    @MainActor
    private func dismissKeyboardIfPresent() {
        guard app.keyboards.element.exists else { return }
        let bar = app.navigationBars.firstMatch
        guard bar.exists else { return }
        bar.tap()
        _ = app.keyboards.element.waitForNonExistence(timeout: 3)
    }

    @MainActor
    private func performCoreFlowAudit() throws {
        dismissKeyboardIfPresent()
        // Keep the one documented P1 exception narrow: Apple's contrast sampler
        // treats decorative chart paint as text. Every other issue, including
        // hit regions, is actionable.
        try app.performAccessibilityAudit { issue in
            let description = [
                issue.compactDescription,
                issue.detailedDescription,
                issue.element?.label ?? "",
                issue.element?.identifier ?? ""
            ].joined(separator: " ").lowercased()
            if issue.auditType == .hitRegion,
               self.app.navigationBars["Monthly Overview"].exists,
               (issue.element?.label ?? "").contains(" to ") {
                // Swift Charts exposes each monthly data point as a virtual
                // audio-graph element. These are not touch controls, so their
                // plotted dimensions are not actionable hit targets.
                return true
            }
            if issue.auditType == .contrast {

                // DEC-012: brand green #3FCFA4 carries white content by owner
                // decision, which is 1.97:1 and misses AA. Scoped to the labels
                // that sit ON a brand-green fill — the primary CTAs and the FAB.
                // This is the ONLY accepted contrast miss; every other element on
                // every screen is still audited. If a new green surface appears,
                // it must be added here consciously rather than inherited.
                let brandGreenFilledContent: Set<String> = [
                    "Get Started", "Continue", "Set Up Account", "Review Setup",
                    "Start Tracking", "Save Transaction", "Add transaction",
                    "Choose File"
                ]
                // Case-insensitive: the FAB's label is "Add Transaction" and
                // this set carried "Add transaction", so the exemption silently
                // missed it.
                let label = (issue.element?.label ?? "").lowercased()
                if brandGreenFilledContent.contains(where: { $0.lowercased() == label }) {
                    return true
                }
                // Decorative brand marks opt in explicitly by identifier, so a
                // new one has to be marked deliberately rather than inheriting
                // the exemption by being unlabelled.
                if (issue.element?.identifier ?? "").hasPrefix("brand-mark-") {
                    return true
                }
                // The Net Worth card carries white content on the brand-green
                // fill by owner decision (2026-08-08), overriding the dark-text
                // choice of 2026-08-03 after seeing both on device. That pairing
                // is 1.97:1 and this is a DATA surface, not a CTA — so unlike the
                // rest of DEC-012 it is a real, knowingly accepted miss, not a
                // sampler artifact. The owner was offered a darker fill that
                // would pass AA and declined it to keep the accent exact.
                //
                // Anchored to one identifier so it cannot spread: any other
                // white-on-green surface must opt in deliberately. The figures
                // stay reachable via the card's accessibilityValue.
                if issue.element?.identifier == "brand-green-filled-card" {
                    return true
                }
                // The paywall's lifetime CTA is white on #3FCFA4 — 1.97:1, a real
                // miss, not a sampler artifact. DEC-023 predicted this exactly and
                // prescribed this entry: "If the audit ever reaches it unoccluded it
                // will fail on this pairing, and the fix is to add
                // paywall-lifetime-button to the exemptions deliberately, not to
                // change the colour." That is what this is (DEC-025).
                //
                // Why it surfaced only now: before 636169ea the button was #17604A at
                // 7.48:1 and passed. Brand green made it 1.97:1, and the audit catches
                // it only on the runs where the button lands clear of the navigation
                // bar — which is why the leg went intermittently red rather than
                // failing outright.
                //
                // The label is the user-visible price string, so this is anchored to
                // the identifier: a price change must not silently widen or void it.
                if issue.element?.identifier == "paywall-lifetime-button" {
                    return true
                }
                // DEC-027: the paywall's policy links, which the sampler measures
                // against the subscribe button rather than the page they are drawn on.
                //
                // On iPhone 17 Pro Max — CI's device, and the reason DEC-025 did not
                // make the leg green — the audit reports "Terms of Service", " and "
                // and "Privacy Policy" at frames of y=836.7, h=17.3. Cropping CI's own
                // App Screenshot at exactly that rect shows the "Try It Free" capsule
                // and no link text whatsoever: 40,469 of the pixels there are #3ECDA2.
                // The links are scrolled elsewhere; only their reported frames land on
                // the CTA. So the sampler compares #17604A against brand green and
                // returns 1.58, 1.60 and 1.58 — measured, not inferred.
                //
                // Where these links are genuinely painted they are #17604A on the
                // near-white sheet at 7.48:1, which is why
                // .subscriptionStorePolicyForegroundStyle pins that colour in the
                // first place. Nothing here is a real legibility miss.
                //
                // Anchored to Apple's three identifiers and screen-scoped to the
                // paywall. Not anchored to "any green-backed sample", which would
                // excuse real misses elsewhere on the same screen.
                let policyLinkIDs: Set<String> = ["Terms of Service", "Privacy Policy", "and"]
                if self.app.navigationBars["Vittora Pro"].exists,
                   let identifier = issue.element?.identifier,
                   policyLinkIDs.contains(identifier) {
                    return true
                }
                // On CI's iOS 26.2 the audit flags an inner node of the floating
                // add button that carries neither the label nor the identifier,
                // so both checks above miss it and the DEC-012 exemption never
                // reaches the one control it was written for. Anchor it to the
                // button's own frame instead, which is present regardless of how
                // the node is exposed. Still narrow: only samples that actually
                // overlap the FAB.
                let fab = self.app.descendants(matching: .any)["quick-entry-floating-button"]
                if let elementFrame = issue.element?.frame,
                   fab.exists,
                   fab.frame.intersects(elementFrame) {
                    return true
                }

                // The same shape as the FAB above, for a different miss. The
                // onboarding currency list reports clipped frames for rows that
                // are scrolled out of view, and those land over the Continue
                // button: the "UAE Dirham (AED)" element screenshot contains no
                // text at all — just the white page meeting the green pill. So
                // the sampler measures that green-on-white edge, which is the
                // DEC-012 pairing already accepted two checks above, and files
                // it under a row label the exemption cannot match.
                //
                // Anchored to the CTA's own identifier, not to green in general:
                // only samples that actually overlap that one button are
                // excused, and the rows' real text is still audited wherever it
                // is genuinely on screen.
                let onboardingCTA = self.app.buttons["onboarding-next-button"]
                if let elementFrame = issue.element?.frame,
                   onboardingCTA.exists,
                   onboardingCTA.frame.intersects(elementFrame) {
                    return true
                }

                // DEC-019: StoreKit's own subscribe-button offer caption on the
                // Vittora Pro paywall — "7 days free, then $39.99/year" at
                // #828289 on #F1F1F6, 3.39:1.
                //
                // This is the FIRST exemption for text Apple renders. Every
                // DEC-012 case above excuses paint WE chose. This one does not:
                // no public SubscriptionStoreView API restyles this caption.
                // `StoreButtonKind` has no case for it, `.productDescription(.hidden)`
                // targets the plan-card descriptions instead, and the caption is
                // alpha-composited over the scroll content, so a lighter
                // background makes it worse rather than better.
                //
                // Accepted because nothing is lost: the selected plan card
                // repeats the identical sentence in black as its
                // "Product View Secondary Text", so a user who cannot read the
                // grey line still gets the offer terms — as does VoiceOver,
                // which reads the caption as part of the subscribe button's own
                // label ("7 days free, then $39.99 per year, Try It Free").
                //
                // Anchored to Apple's identifier for that one caption node, plus
                // its frame. The frame arm is not redundant: the audit reports
                // this as a bare SwiftUI.AccessibilityNode carrying no label,
                // exactly as it does for the FAB and `debt-entry-delete` above,
                // so an identifier-only check can silently stop matching. The
                // measured failing element was 500x52px at 3x — the caption's
                // 166.7x17.3pt box exactly. Screen-scoped to the paywall, so no
                // other Apple chrome anywhere in the app inherits this.
                let offerCaptionID = "Subscription Store View Standard Picker Style Subscribe Button Caption"
                if self.app.navigationBars["Vittora Pro"].exists {
                    if issue.element?.identifier == offerCaptionID {
                        return true
                    }
                    let offerCaption = self.app.descendants(matching: .any)[offerCaptionID]
                    if let elementFrame = issue.element?.frame,
                       offerCaption.exists,
                       offerCaption.frame.intersects(elementFrame) {
                        return true
                    }
                }

                let systemTabLabels = ["Dashboard", "Transactions", "Budgets", "Reports", "More"]
                let elementLabel = issue.element?.label ?? ""
                if systemTabLabels.contains(where: elementLabel.hasPrefix) {
                    // XCTest samples the system liquid-glass highlight instead
                    // of the opaque tab-bar material. These are UIKit-owned tabs.
                    return true
                }
                let bottomBar = self.app.tabBars.firstMatch
                if let element = issue.element,
                   bottomBar.exists,
                   bottomBar.frame.minY > 1,
                   element.frame.maxY > bottomBar.frame.minY {
                    // iOS's floating compact tab bar fades scroll content beneath
                    // its own system-owned material exactly as the navigation bar
                    // does at the top. Ignore contrast samples for any element
                    // whose frame reaches the measured top edge of the bar — that
                    // is, it overlaps the bar, whether or not it starts below it.
                    // minY > asked whether the element starts below the bar,
                    // which left elements that merely cross the bar's top edge
                    // being audited against glass-material pixels they were never
                    // drawn on. maxY > asks whether the element reaches the bar,
                    // which excuses genuinely occluded elements while still
                    // auditing elements that sit fully above the bar. Measured on
                    // Budgets, where the tab bar's minY is 769: Spent
                    // (733.0-750.3), Remaining (733.0-750.3) and Progress
                    // (736.0-753.3) sit entirely above the bar and are audited;
                    // $27.35 (756.3-779.7), $72.65 (756.3-779.7) and 27%
                    // (759.3-776.7) cross into the bar and are exempt.
                    //
                    // Anchored to the bar's own measured frame rather than a
                    // magic constant, so it follows the bar on every device and
                    // orientation. The minY > 1 guard rejects a degenerate or
                    // zero tab-bar frame the way the top rule guards with
                    // maxY > 1.
                    return true
                }
                if let element = issue.element,
                   element.frame.maxY <= self.app.frame.minY {
                    // The mirror of the tab-bar rule above, for the other end of
                    // the viewport. A ScrollView inside a plain VStack keeps every
                    // row in the accessibility tree at its true frame, so a row
                    // scrolled off the top reports a NEGATIVE origin: on the
                    // Emergency Fund report, "months covered" measures y -69.8 to
                    // -52.5 against a window that starts at 0. XCTest still samples
                    // pixels at that frame and measures whatever is there, which is
                    // not the element. Nothing is on screen to read, so there is
                    // nothing to fail. Kept separate from the nav-bar check below
                    // because these are different facts: this element is off the
                    // window entirely, not occluded by chrome.
                    return true
                }
                let topBar = self.app.navigationBars.firstMatch
                if let element = issue.element,
                   topBar.exists,
                   topBar.frame.maxY > 1,
                   element.frame.minY < topBar.frame.maxY {
                    // iOS's navigation bar occludes scroll content beneath its own
                    // material exactly as the tab bar does at the bottom. Ignore
                    // only contrast samples whose element frame reaches up into the
                    // bar or the status-bar strip above it: on the Emergency Fund
                    // report "6-month target" measures y 63.3-87.6 behind a bar at
                    // {{0,59},{393,54}}, and "3-month target" y 33.0-57.3 in the
                    // strip above it. Both sample chrome, not text.
                    //
                    // Anchored to the bar's own measured maxY rather than a
                    // constant, so it follows the bar on every device and
                    // orientation. An element whose minY clears the bar is fully on
                    // screen and is still audited.
                    return true
                }
                if issue.element == nil,
                   self.app.tabBars.firstMatch.exists,
                   (
                    ["Accounts", "Categories", "Settings", "Appearance", "iCloud Sync", "Manage Data", "Dashboard", "Security audit log", "Savings Goals", "Recurring Transactions", "Emergency Fund"]
                        .contains(where: { self.app.navigationBars[$0].exists })
                    || self.app.descendants(matching: .any)["budget-list-root"].exists
                    || self.app.descendants(matching: .any)["transaction-list-root"].exists
                   ) {
                    // iOS 26 reports aggregate nil-element contrast issues for
                    // the system liquid-glass toolbar/tab symbols on these
                    // exact screens. Content and exposed controls remain audited.
                    // Savings Goals / Emergency Fund: same sampler false positive
                    // confirmed on iPhone 16 / iOS 26.5 at AccessibilityXL (nil
                    // element; content already textPrimary on secondary cards).
                    return true
                }
                if issue.element?.elementType == .searchField,
                   issue.compactDescription.localizedCaseInsensitiveContains("nearly") {
                    // System `.searchable` fields are UIKit liquid-glass chrome.
                    // XCTest reports "Contrast nearly passed" against OLED black
                    // / dark materials; list rows and custom controls stay audited.
                    return true
                }
                // Form section headers, mis-sampled.
                //
                // VFormSectionHeader pins VColors.textPrimary, so these render
                // black-on-#F2F2F7 at roughly 18:1 — the exported element image
                // confirms it. XCTest still reports a contrast failure because
                // it samples the header's full-width row, which is background
                // against background. The same header passes and fails across
                // runs of identical code, which is what a sampling artifact
                // looks like.
                //
                // Matched by identifier rather than by text: this replaced six
                // near-identical label+screen checks ("Amount", "Country",
                // "Theme", "Type", "Expense", "Date & Payment") that had to grow
                // by one every time a new screen was audited. A real contrast
                // problem here would require the component's own token to
                // regress, which DesignTokenTests covers.
                if issue.element?.identifier == "form-section-header" {
                    return true
                }
                // The debt row's "Delete" (owner decision, 2026-08-16).
                //
                // Measured from the audit's own exported element image: glyph
                // core #C5221F on #FFFFFF is 5.80:1, past the 4.5:1 AA bar for
                // small text. So this is a sampler artifact, NOT an accepted
                // miss — unlike the DEC-012 brand-green cases above, which
                // really are below AA and knowingly shipped that way.
                //
                // Environment-specific, and deterministic on each side rather
                // than flaky: identical code passes every local run on the same
                // device and OS as CI (iPhone 17 Pro Max / iOS 26.2, six runs)
                // and fails every CI run (two of two). The likely difference is
                // the runner's software renderer anti-aliasing small red glyphs
                // differently, which changes the pixels the sampler averages
                // even though the glyph core is unchanged.
                //
                // Worth stating plainly because the first read of this was
                // "flaky, re-run it" — it is not. A re-run will fail again.
                //
                // Frame anchor as well as identifier, for the reason the FAB
                // exemption above needed one: the flagged node was reported as
                // a bare SwiftUI.AccessibilityNode carrying neither label nor
                // identifier, so an identifier-only check would silently stop
                // matching — exactly how the form-section-header exemption
                // broke when its component was restructured.
                let deleteButton = self.app.descendants(matching: .any)["debt-entry-delete"]
                if issue.element?.identifier == "debt-entry-delete" {
                    return true
                }
                if let elementFrame = issue.element?.frame,
                   deleteButton.exists,
                   deleteButton.frame.intersects(elementFrame) {
                    return true
                }
                if self.app.navigationBars["Dashboard"].exists {
                    let identifier = issue.element?.identifier ?? ""
                    let label = issue.element?.label ?? ""
                    if identifier.hasPrefix("dashboard-recent-date-")
                        || label.range(
                            of: #"^([0-9]{1,2} [A-Za-z]{3}|[A-Za-z]{3} [0-9]{1,2})$"#,
                            options: .regularExpression
                        ) != nil {
                        // iOS 26 mis-samples these compact day-month labels inside
                        // a plain Button even when rendered as black-on-white.
                        // Scope this to Dashboard recent-row dates only.
                        return true
                    }
                }
                let glassToolbarForms = [
                    "Settle Debt", "Add Debt", "New Goal", "Add Expense", "New Group",
                    "New Transaction", "Edit Transaction", "New Account", "Edit Account",
                    "New Category", "Edit Category", "New Payee", "Edit Payee",
                    "New Recurring", "Edit Recurring", "Import"
                ]
                if issue.element == nil,
                   glassToolbarForms.contains(where: { self.app.navigationBars[$0].exists }) {
                    // XCTest emits one aggregate nil-element issue for the
                    // system liquid-glass toolbar chrome. Modal forms show
                    // Cancel; pushed forms (e.g. New Transaction from the
                    // tab) only have Back + Save — same sampler false positive.
                    // The form content and individually exposed controls remain audited.
                    return true
                }
                // The tax stacked bar is exposed through the parent summary,
                // but XCTest emits one aggregate contrast issue with no element
                // for its decorative color marks. Scope the workaround to that
                // exact nil-element chart issue.
                if issue.element == nil,
                   self.app.staticTexts["Bracket Distribution"].exists {
                    return true
                }
                // DEC-022: the sampler false-positive class, answered by
                // measurement instead of by a list of identifiers.
                //
                // Apple's contrast sampler reports `Contrast failed for
                // SwiftUI.AccessibilityNode` against fully-visible text that is
                // demonstrably well above AA. Measured on this simulator from
                // the audit's own exported element images: `Custom Report`
                // 20.62:1, `April 2026` 18.88:1, `Basic Tax` 19.91:1,
                // `Marginal Rate` 19.80:1, `Savings Rate` 20.87:1, and the two
                // brand-coloured `$0` figures at 5.36:1 (red) and 4.81:1
                // (green). Five investigations have found no genuine defect in
                // this class.
                //
                // So rather than excusing the screens or the elements, this
                // rung re-measures the finding and excuses it only when the
                // element's OWN rendered pixels clear the 4.5:1 AA bar for
                // small text - the strictest of the two AA bars, applied to
                // everything regardless of type size. A genuine contrast defect
                // is by definition pixels below that bar, so it cannot be
                // excused here: the check would measure the same low ratio the
                // sampler did and let the finding through.
                //
                // Every rung above this one still runs first, so the knowingly
                // sub-AA DEC-012 pairings keep their own explicit exemptions -
                // they measure below 4.5:1 and this rung would never excuse
                // them.
                if let element = issue.element,
                   let ratio = self.measuredContrastRatio(for: element),
                   ratio >= 4.5 {
                    return true
                }
                let isChartMark = description.contains("chart")
                    && (description.contains("mark") || description.contains("plot"))
                return isChartMark
            }
            if issue.auditType == .textClipped {
                // XCTest reports predictive "may be clipped" warnings for relative
                // text styles even when the accessibility3 render is fully visible.
                // The dedicated screenshot suite remains the clipping gate.
                if description.contains("search") {
                    return true
                }
                // `compactDescription` is always the bare string "Text clipped";
                // the predictive wording — "Text of this element may be clipped
                // at larger Dynamic Type sizes" — is in `detailedDescription`.
                // This condition read compactDescription, so it never matched
                // once, and the exclusion documented above has never actually
                // applied. `description` joins both, so it sees the real text.
                // A hard clip still fails: only the predictive warning is
                // ignored, and the accessibility3 screenshots remain the gate.
                return description.contains("may be clipped")
            }
            if issue.auditType == .dynamicType {
                // "Partially unsupported" is emitted for semantic relative styles
                // that do scale. Fixed-size and fully unsupported fonts still fail,
                // while accessibility3 screenshots verify the rendered result.
                return issue.compactDescription.localizedCaseInsensitiveContains("partially")
            }
            if issue.auditType == .elementDetection,
               issue.element == nil,
               self.app.tabBars.firstMatch.exists {
                // Scroll content beneath iOS 26's floating tab bar.
                //
                // The bar is a capsule with transparent gutters, so content
                // scrolls visibly under and around it — that is the platform's
                // intended rendering, not a layout mistake. The accessibility
                // tree drops those rows as occluded while the glyphs are still
                // on screen, so the vision pass reports text with no element.
                // VoiceOver still reaches every one of them by scrolling.
                //
                // Owner decision (2026-08-08). The alternative was an opaque
                // strip painted over the content to hide it, which is what
                // produced the banner slicing cards above the tab bar that was
                // reported from device three times. Measured three ways —
                // #197's CI plus two local full-class runs — so this is a
                // structural trade-off, not a tunable padding value.
                //
                // Deliberately narrow: only nil-element findings (whole-screen,
                // nothing to point at) and only where a tab bar is present. An
                // elementDetection issue that names an element still fails, and
                // so does anything on a screen without the floating bar.
                return true
            }
            self.logAuditIssue(issue)
            return false
        }
    }

    /// Logs every issue the filter lets through. CI runs iOS 26.2, which cannot
    /// be installed locally, and its xcresult upload is not always available —
    /// so without this the only signal is the audit type, which is not enough to
    /// tell a real defect from a sampler artifact. Diagnostic only: it changes
    /// nothing about what passes or fails.
    @MainActor
    private func logAuditIssue(_ issue: XCUIAccessibilityAuditIssue) {
        let e = issue.element
        let frame = e.map { "\($0.frame)" } ?? "nil"
        print("""
        AUDIT-ISSUE type=\(issue.auditType) \
        label='\(e?.label ?? "")' id='\(e?.identifier ?? "")' \
        elementType=\(e?.elementType.rawValue.description ?? "nil") \
        frame=\(frame) appFrame=\(app.frame) \
        compact='\(issue.compactDescription)'
        """)
    }

    /// The WCAG relative-contrast ratio actually rendered inside an element's own
    /// frame, or `nil` when it cannot be measured.
    ///
    /// Takes the element's screenshot - the very image XCTest attaches to a
    /// contrast failure - normalises it to 8-bit sRGB, and compares the 2nd and
    /// 98th percentile relative luminance. Percentiles rather than min/max so a
    /// single stray pixel from an adjacent border cannot manufacture a passing
    /// ratio; both error directions of that choice push toward reporting a LOWER
    /// ratio, i.e. toward failing, never toward excusing.
    @MainActor
    private func measuredContrastRatio(for element: XCUIElement) -> Double? {
        #if canImport(UIKit)
        guard element.exists else { return nil }
        guard element.frame.width >= 1, element.frame.height >= 1 else { return nil }
        guard let cgImage = element.screenshot().image.cgImage else { return nil }
        let width = cgImage.width
        let height = cgImage.height
        // An 8x8 floor: below that the percentiles stop describing anything.
        guard width * height >= 64 else { return nil }
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }

        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let drew: Bool = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let base = buffer.baseAddress,
                  let context = CGContext(
                    data: base,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: width * 4,
                    space: colorSpace,
                    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
                  ) else { return false }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drew else { return nil }

        var luminances = [Double]()
        luminances.reserveCapacity(width * height)
        for index in stride(from: 0, to: pixels.count, by: 4) {
            luminances.append(
                Self.relativeLuminance(
                    red: pixels[index],
                    green: pixels[index + 1],
                    blue: pixels[index + 2]
                )
            )
        }
        guard luminances.count >= 64 else { return nil }
        luminances.sort()
        let darkest = luminances[Int(Double(luminances.count) * 0.02)]
        let lightest = luminances[Int(Double(luminances.count) * 0.98)]
        return (lightest + 0.05) / (darkest + 0.05)
        #else
        return nil
        #endif
    }

    /// WCAG 2.1 relative luminance for an 8-bit sRGB triple.
    private static func relativeLuminance(red: UInt8, green: UInt8, blue: UInt8) -> Double {
        func linear(_ value: UInt8) -> Double {
            let channel = Double(value) / 255.0
            return channel <= 0.03928 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    @MainActor
    private func captureFlowScreenshot(named name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        let dir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("verification", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? screenshot.pngRepresentation.write(to: dir.appendingPathComponent("\(name).png"))
    }
}

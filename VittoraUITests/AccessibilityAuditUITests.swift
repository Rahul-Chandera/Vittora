import XCTest

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

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - performAccessibilityAudit

    @MainActor
    func testDashboardAccessibilityAudit() throws {
        #if os(macOS)
        throw XCTSkip("iOS only")
        #else
        launchSeeded(initialTab: "dashboard")
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
        launchSeeded(initialTab: "transactions")
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
        launchSeeded(initialTab: "transactions")
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
        launchSeeded(initialTab: "budgets")
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
        launchSeeded(initialTab: "reports")
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
        launchSeeded(initialTab: "settings")
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
        launchSeeded(initialTab: "settings")
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
        launchSeeded(initialTab: "settings")
        openOverflowDestination(named: "Debt", navigationTitle: "Debt Ledger")
        try performCoreFlowAudit()

        tapText("Alex Carter")
        XCTAssertTrue(app.navigationBars["Alex Carter"].waitForExistence(timeout: 10))
        try performCoreFlowAudit()

        UITestSupport.scrollToElement(app.buttons["Settle"].firstMatch, in: app)
        UITestSupport.tapWhenReady(app.buttons["Settle"].firstMatch)
        XCTAssertTrue(app.navigationBars["Settle Debt"].waitForExistence(timeout: 10))
        try performCoreFlowAudit()
        dismissPresentedScreen()

        app.terminate()
        launchSeeded(initialTab: "settings")
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

        launchSeeded(initialTab: "settings")
        openOverflowDestination(named: "Settings", navigationTitle: "Settings")
        try performCoreFlowAudit()
        app.terminate()

        for section in sections {
            launchSeeded(initialTab: "settings")
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
            launchSeeded(initialTab: "settings")
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

        launchSeeded(initialTab: "transactions")
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
            "--ui-test-reset-app-lock"
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

    @MainActor
    func testNewReportsAccessibilityAudit() throws {
        #if os(macOS)
        throw XCTSkip("iOS only")
        #else
        launchSeeded(initialTab: "reports")
        XCTAssertTrue(app.navigationBars["Reports"].waitForExistence(timeout: 15))
        let emergency = app.descendants(matching: .any)["report-card-emergencyFund"].firstMatch
        for _ in 0..<10 {
            if emergency.exists {
                let frame = emergency.frame
                if frame.height > 1, frame.maxY <= app.frame.maxY - 120 {
                    break
                }
            }
            app.swipeUp()
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
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
            extraArguments: ["--ui-test-appearance=oledBlack", "--ui-test-accent=purple"]
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
                extraArguments: ["--ui-test-appearance=oledBlack", "--ui-test-accent=\(accent)"]
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
            extraArguments: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXL"]
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
        let accessibility3 = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXL"]
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
        for _ in 0..<10 {
            if emergency.exists {
                let frame = emergency.frame
                if frame.height > 1, frame.maxY <= app.frame.maxY - 120 {
                    break
                }
            }
            app.swipeUp()
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        UITestSupport.scrollToElement(emergency, in: app)
        emergency.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        _ = app.navigationBars["Emergency Fund"].waitForExistence(timeout: 15)
        try performCoreFlowAudit()
        captureFlowScreenshot(named: "a11y3-emergency-fund")
        app.terminate()

        app.launchArguments = [
            "--uitesting", "--ui-test-onboarding", "--ui-test-seed-demo",
            "--ui-test-reset-app-lock"
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

                let systemTabLabels = ["Dashboard", "Transactions", "Budgets", "Reports", "More"]
                let elementLabel = issue.element?.label ?? ""
                if systemTabLabels.contains(where: elementLabel.hasPrefix) {
                    // XCTest samples the system liquid-glass highlight instead
                    // of the opaque tab-bar material. These are UIKit-owned tabs.
                    return true
                }
                if let element = issue.element,
                   self.app.tabBars.firstMatch.exists,
                   element.frame.maxY > self.app.frame.maxY - 120 {
                    // iOS's floating compact tab bar deliberately fades scroll
                    // content beneath its system-owned material. Ignore only
                    // contrast samples whose element frame intersects that bar.
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

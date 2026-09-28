#if os(iOS)
import XCTest

/// Marketing screenshots for social media, the website, blogs and ad creative.
///
/// Not a test: every case is skipped unless `MARKETING_SCREENSHOT_DIR` reaches the
/// runner (pass it as `TEST_RUNNER_MARKETING_SCREENSHOT_DIR`), so CI never runs it.
/// `Scripts/store/capture_marketing_screenshots.sh` drives it per device and
/// appearance.
///
/// Same showcase data as the App Store gallery (`--ui-test-seed-demo`, US region,
/// USD, en_US), plus the household demo. Files are named for an AI agent to read
/// without opening them:
///
///     <platform>-<appearance>-<NN>-<feature-area>-<screen>.png
///     iphone-dark-08-budgets-household-shared-budgets.png
///
/// NN orders the gallery by product area. A screen that cannot be reached is
/// reported as a failure and NOT captured, so a file never shows the wrong screen.
final class MarketingScreenshotsUITests: XCTestCase {
    private var app: XCUIApplication!
    private var outputDirectory: URL?
    private var appearance = "light"
    private var platform = "iphone"

    override func setUpWithError() throws {
        let environment = ProcessInfo.processInfo.environment
        guard let path = environment["MARKETING_SCREENSHOT_DIR"], !path.isEmpty else {
            throw XCTSkip("Marketing capture only — set TEST_RUNNER_MARKETING_SCREENSHOT_DIR.")
        }
        outputDirectory = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: outputDirectory!, withIntermediateDirectories: true)
        appearance = environment["MARKETING_APPEARANCE"] ?? "light"
        platform = UIDevice.current.userInterfaceIdiom == .pad ? "ipad" : "iphone"
        // One unreachable screen must not cost the rest of the group.
        continueAfterFailure = true
    }

    // MARK: - Core: dashboard, transactions, budgets

    @MainActor
    func test01Core() throws {
        launch(tab: "dashboard", extra: ["--ui-test-hide-quick-entry"])
        shot(1, "dashboard", "overview", when: app.navigationBars["Dashboard"])
        app.swipeUp()
        shot(2, "dashboard", "insights-and-recent-activity")

        launch(tab: "transactions")
        shot(3, "transactions", "list", when: app.descendants(matching: .any)["transaction-list-root"])
        // A categorised purchase with a payee, not the first row (a debt
        // settlement with neither).
        let row = app.staticTexts["Lunch Order"].firstMatch
        if row.waitForExistence(timeout: 10) {
            row.tap()
            shot(4, "transactions", "detail", when: app.buttons["Edit transaction"])
        }

        launch(tab: "transactions")
        let add = app.buttons["transaction-add-button"].exists
            ? app.buttons["transaction-add-button"] : app.buttons["Add Transaction"].firstMatch
        if add.waitForExistence(timeout: 15) {
            add.tap()
            let amount = app.textFields["transaction-amount-field"]
            if amount.waitForExistence(timeout: 10) {
                amount.typeText("42.50")
                dismissKeyboard()
                shot(5, "transactions", "add-expense-form")
            }
        }

        launch(tab: "budgets")
        shot(6, "budgets", "monthly-budgets", when: app.navigationBars["Budgets"])
        let budget = app.descendants(matching: .any)["budget-row"].firstMatch
        if budget.waitForExistence(timeout: 10) {
            budget.tap()
            shot(7, "budgets", "budget-detail", when: app.navigationBars.element(boundBy: 0))
        }
    }

    // MARK: - Household sharing (M3.4)

    @MainActor
    func test02Household() throws {
        launch(tab: "budgets", extra: ["--ui-test-seed-household"])
        let household = app.buttons["budget-household-button"]
        guard household.waitForExistence(timeout: 15) else { return XCTFail("No Household button") }
        household.tap()
        shot(8, "budgets", "household-shared-budgets", when: app.staticTexts["Shared Budgets"])
        let row = app.descendants(matching: .any)["household-budget-row"].firstMatch
        if row.waitForExistence(timeout: 10) {
            row.tap()
            shot(9, "budgets", "household-spending-by-member", when: app.staticTexts["By Member This Month"])
        }
    }

    // MARK: - Reports

    @MainActor
    func test03Reports() throws {
        launch(tab: "reports")
        shot(10, "reports", "all-reports", when: app.navigationBars["Reports"])

        let reports: [(String, String)] = [
            ("monthly", "monthly-overview"),
            ("category", "category-breakdown"),
            ("trends", "spending-trends"),
            ("cashFlow", "cash-flow"),
            ("cashFlowForecast", "cash-flow-forecast"),
            ("annual", "annual-summary"),
            ("netWorth", "net-worth-history"),
            ("subscriptionAudit", "subscription-audit"),
            ("fiftyThirtyTwenty", "50-30-20-budget-rule"),
            ("emergencyFund", "emergency-fund"),
            ("healthScore", "financial-health-score"),
            ("spendingOutlook", "spending-outlook-and-what-if"),
            ("yearInReview", "year-in-review"),
            ("custom", "custom-report-builder"),
        ]
        for (offset, report) in reports.enumerated() {
            launch(tab: "reports", extra: ["--ui-test-open-url=vittora://report/\(report.0)"])
            // The report pushes over Reports; once it has, Reports is no longer
            // the top title.
            let pushed = app.navigationBars.matching(NSPredicate(format: "identifier != 'Reports'")).firstMatch
            if report.0 == "emergencyFund" {
                // The seed counts no account toward the fund, which reads as
                // "0.0 months covered". Count the checking account, as a user would.
                let checking = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Chase Checking'")).firstMatch
                scrollTo(checking)
                if checking.waitForExistence(timeout: 10) { checking.tap() }
                for _ in 0..<4 { app.swipeDown() }
            }
            shot(11 + offset, "reports", report.1, when: pushed, settle: 4)
        }
    }

    // MARK: - Savings, debt, splits, tax

    @MainActor
    func test04MoneyTools() throws {
        openOverflow("Savings", title: "Savings Goals")
        shot(30, "savings", "goals", when: app.navigationBars["Savings Goals"])
        tapText("Emergency Fund")
        shot(31, "savings", "goal-detail", when: app.navigationBars["Emergency Fund"])

        openOverflow("Debt", title: "Debt Ledger")
        shot(32, "debt", "ledger", when: app.navigationBars["Debt Ledger"])
        let analytics = app.buttons["debt-analytics-button"]
        if analytics.waitForExistence(timeout: 10) {
            analytics.tap()
            shot(33, "debt", "analytics", when: app.navigationBars["Debt Analytics"])
            // Reopen rather than tap "back": on iPad the first navigation-bar
            // button is the sidebar toggle.
            openOverflow("Debt", title: "Debt Ledger")
        }
        tapText("Alex Carter")
        shot(34, "debt", "person-detail", when: app.navigationBars["Alex Carter"])

        openOverflow("Splits", title: "Split Expenses")
        shot(35, "splits", "groups", when: app.navigationBars["Split Expenses"])
        tapText("Lake House Weekend")
        shot(36, "splits", "group-detail-balances", when: app.navigationBars["Lake House Weekend"])

        openOverflow("Tax", title: "Tax Estimator")
        shot(37, "tax", "estimator", when: app.staticTexts["Bracket Distribution"], settle: 3)
        let breakdown = app.buttons["Full Bracket Breakdown"].firstMatch
        scrollTo(breakdown)
        if breakdown.exists {
            breakdown.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2)).tap()
            shot(38, "tax", "bracket-breakdown", when: app.navigationBars["Tax Breakdown"])
        }
    }

    // MARK: - Recurring, accounts, lists

    @MainActor
    func test05RecurringAndLists() throws {
        openSettingsRow("Recurring", title: "Recurring Transactions")
        shot(40, "recurring", "bills-and-subscriptions", when: app.navigationBars["Recurring Transactions"])
        tapText("Rent")
        shot(41, "recurring", "bill-detail", when: app.navigationBars["Recurring Details"])

        openSettingsRow("Accounts", title: "Accounts")
        shot(42, "accounts", "list", when: app.navigationBars["Accounts"])
        tapText("Chase Checking")
        shot(43, "accounts", "account-detail", when: app.navigationBars["Chase Checking"])

        openSettingsRow("Categories", title: "Categories")
        shot(44, "categories", "list", when: app.navigationBars["Categories"])

        openSettingsRow("Payees", title: "Payees")
        shot(45, "payees", "list", when: app.navigationBars["Payees"])
    }

    // MARK: - Shopping mode (M3.3)

    @MainActor
    func test06ShoppingMode() throws {
        launch(tab: "settings")
        let row = app.descendants(matching: .any)["more-shopping-mode-row"].firstMatch
        guard row.waitForExistence(timeout: 15) else {
            // iPad's sidebar has no More hub, so Shopping Mode has no row there.
            throw XCTSkip("Shopping Mode has no entry point on \(platform).")
        }
        row.tap()
        let picker = app.buttons["shopping-mode-budget-picker"]
        if picker.waitForExistence(timeout: 10) {
            picker.tap()
            let groceries = app.buttons["Groceries"].firstMatch
            if groceries.waitForExistence(timeout: 5) { groceries.tap() }
        }
        shot(50, "shopping-mode", "start-with-budget", when: app.buttons["shopping-mode-start-button"])
        app.buttons["shopping-mode-start-button"].tap()
        let amount = app.textFields["shopping-mode-amount-field"]
        for price in ["12.99", "8.49", "23.75"] where amount.waitForExistence(timeout: 5) {
            amount.tap()
            amount.typeText(price)
            app.buttons["Add"].firstMatch.tap()
        }
        dismissKeyboard()
        shot(51, "shopping-mode", "running-total-and-budget-left", when: app.staticTexts["shopping-mode-total"])
        // The same total, live in the Dynamic Island.
        XCUIDevice.shared.press(.home)
        RunLoop.current.run(until: Date().addingTimeInterval(3))
        shot(52, "live-activities", "shopping-total-in-dynamic-island")
    }

    // MARK: - Settings

    @MainActor
    func test07Settings() throws {
        openOverflow("Settings", title: "Settings")
        shot(60, "settings", "overview", when: app.navigationBars["Settings"])
        let sections: [(String, String, String)] = [
            ("Appearance", "Appearance", "appearance-and-themes"),
            ("App Lock", "Security", "app-lock-and-privacy"),
            ("Manage Data", "Manage Data", "export-and-backup"),
            ("Notifications", "Notifications", "notifications"),
        ]
        for (offset, section) in sections.enumerated() {
            openOverflow("Settings", title: "Settings")
            tapText(section.0)
            shot(61 + offset, "settings", section.2, when: app.navigationBars[section.1])
        }
    }

    // MARK: - Pro and onboarding

    @MainActor
    func test08PaywallAndOnboarding() throws {
        openOverflow("Settings", title: "Settings", pro: false)
        let proRow = app.descendants(matching: .any)["settings-vittora-pro"].firstMatch
        scrollTo(proRow)
        if proRow.waitForExistence(timeout: 15) { proRow.tap() }
        // StoreKit fills the store in asynchronously; the disclosure renders last.
        _ = app.descendants(matching: .any)["paywall-auto-renew-disclosure"].waitForExistence(timeout: 20)
        shot(70, "pro", "paywall", when: app.navigationBars["Vittora Pro"], settle: 2)

        app = XCUIApplication()
        app.launchArguments = baseArguments + ["--ui-test-onboarding"]
        app.launch()
        if platform == "ipad" { XCUIDevice.shared.orientation = .landscapeLeft }
        shot(71, "onboarding", "welcome", when: app.buttons["Get Started"], settle: 2)
    }

    // MARK: - Helpers

    private var baseArguments: [String] {
        [
            "--uitesting", "--ui-test-reset-app-lock", "--ui-test-appearance=\(appearance)",
            "--ui-test-user-name=Alex",
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryLarge",
        ]
    }

    /// A fresh app per screen group: nothing a previous screen left behind
    /// (a sheet, a scroll position, a focused field) can leak into the next shot.
    @MainActor
    private func launch(tab: String, pro: Bool = true, extra: [String] = []) {
        app?.terminate()
        app = XCUIApplication()
        app.launchArguments = baseArguments + ["--ui-test-seed-demo"] + (pro ? ["--ui-test-pro"] : []) + extra
        app.launchEnvironment["UITEST_INITIAL_TAB"] = tab
        app.launchEnvironment["UITEST_DEMO_REGION"] = "US"
        app.launchEnvironment["UITEST_DEMO_MONTHS"] = "12"
        app.launch()
        // iPad in landscape, like the App Store gallery: sidebar and detail side
        // by side, which is what the regular-width layout is for.
        if platform == "ipad" { XCUIDevice.shared.orientation = .landscapeLeft }
        XCTAssertTrue(UITestSupport.waitForContentRoot(in: app, timeout: 20))
        // A year of history seeds asynchronously and report aggregates reload
        // once it lands — the App Store capture script waits the same way.
        RunLoop.current.run(until: Date().addingTimeInterval(8))
    }

    @MainActor
    private func openOverflow(_ name: String, title: String, pro: Bool = true) {
        if platform == "ipad" {
            // Regular width declares every section as a tab, so launch straight
            // into it. iPadOS 26 collapses the sidebar into a top section bar in
            // landscape, so there is no sidebar button to tap, and hunting for
            // one with scrollToElement swiped the content instead.
            launch(tab: name.lowercased(), pro: pro)
            XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 15), "\(title) should open")
            return
        }
        launch(tab: "settings", pro: pro)
        let destination = app.buttons[name].firstMatch
        scrollTo(destination)
        guard destination.waitForExistence(timeout: 15) else { return XCTFail("No \(name) entry") }
        destination.tap()
        XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 15), "\(title) should open")
    }

    @MainActor
    private func openSettingsRow(_ row: String, title: String) {
        openOverflow("Settings", title: "Settings")
        tapText(row)
        _ = app.navigationBars[title].waitForExistence(timeout: 15)
    }

    @MainActor
    private func tapText(_ text: String) {
        let staticText = app.staticTexts[text].firstMatch
        let element = staticText.waitForExistence(timeout: 5)
            ? staticText
            : app.descendants(matching: .any)
                .matching(NSPredicate(format: "label == %@ OR label CONTAINS %@", text, text)).firstMatch
        scrollTo(element)
        if element.waitForExistence(timeout: 10) { element.tap() }
    }

    @MainActor
    private func scrollTo(_ element: XCUIElement) {
        UITestSupport.scrollToElement(element, in: app)
    }

    @MainActor
    private func firstTransactionRow() -> XCUIElement {
        let predicate = NSPredicate(format: "identifier BEGINSWITH %@", "transaction-row-")
        return app.descendants(matching: .any).matching(predicate).firstMatch
    }

    @MainActor
    private func dismissKeyboard() {
        guard app.keyboards.element.exists else { return }
        let done = app.buttons["amount-keyboard-done"]
        if done.exists { done.tap() } else { app.navigationBars.firstMatch.tap() }
        _ = app.keyboards.element.waitForNonExistence(timeout: 5)
    }

    /// Captures only once `element` is on screen, so a navigation that failed
    /// is a reported failure rather than a mislabelled file.
    @MainActor
    private func shot(
        _ index: Int, _ area: String, _ screen: String,
        when element: XCUIElement? = nil, settle: TimeInterval = 1.5
    ) {
        let name = String(format: "%@-%@-%02d-%@-%@", platform, appearance, index, area, screen)
        if let element, !element.waitForExistence(timeout: 20) {
            XCTFail("\(name): screen not reached, not captured")
            return
        }
        RunLoop.current.run(until: Date().addingTimeInterval(settle))
        guard let outputDirectory else { return }
        let url = outputDirectory.appendingPathComponent(name + ".png")
        do {
            try XCUIScreen.main.screenshot().pngRepresentation.write(to: url)
        } catch {
            XCTFail("\(name): \(error)")
        }
    }
}
#endif

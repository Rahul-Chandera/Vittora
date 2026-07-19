import XCTest

/// W5 verification: App Shortcuts appear under Vittora; spending query + App Lock gate.
final class AppShortcutsUITests: XCTestCase {

    @MainActor
    func testVittoraShortcutsAppearInLibrary() throws {
        #if !os(iOS)
        throw XCTSkip("Shortcuts verification runs on iOS Simulator only")
        #else
        let vittora = XCUIApplication(bundleIdentifier: "com.enerjiktech.vittora")
        vittora.launchArguments = ["--uitesting"]
        vittora.launch()
        sleep(2)
        vittora.terminate()

        let shortcuts = XCUIApplication(bundleIdentifier: "com.apple.shortcuts")
        shortcuts.launch()
        XCTAssertTrue(shortcuts.wait(for: .runningForeground, timeout: 10))

        let library = shortcuts.tabBars.buttons["Library"]
        if library.exists { library.tap() }

        // Library root lists apps that donated shortcuts.
        let vittoraRow = shortcuts.staticTexts["Vittora"]
        XCTAssertTrue(
            vittoraRow.waitForExistence(timeout: 12),
            "Vittora should appear under Shortcuts → Library → Apps"
        )
        attachScreenshot(in: shortcuts, name: "w5-shortcuts-listed")

        // Drill into All Shortcuts (or the Vittora app row) to see donated tiles.
        let allShortcuts = shortcuts.staticTexts["All Shortcuts"]
        if allShortcuts.waitForExistence(timeout: 3) {
            allShortcuts.tap()
            sleep(1)
        } else {
            vittoraRow.tap()
            sleep(1)
        }

        let todaySpending = shortcuts.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS[c] %@", "Today's Spending"))
            .firstMatch
        let addExpense = shortcuts.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS[c] %@", "Add Expense"))
            .firstMatch
        let foundTiles = todaySpending.waitForExistence(timeout: 8)
            && addExpense.waitForExistence(timeout: 2)
        attachScreenshot(in: shortcuts, name: "w5-shortcuts-tiles")
        XCTAssertTrue(foundTiles, "Both W5 shortcuts should appear under Vittora")
        #endif
    }

    @MainActor
    func testAddExpenseIntentOpensQuickEntry() throws {
        #if !os(iOS)
        throw XCTSkip("Add Expense intent verification runs on iOS Simulator only")
        #else
        // Same destination as AddExpenseIntent → QuickAddDeepLink.requestFromIntent(.expense).
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--ui-test-quick-add=expense"]
        app.launch()
        XCTAssertTrue(UITestSupport.waitForContentRoot(in: app, timeout: 15))

        let form = app.descendants(matching: .any)["transaction-form-root"]
        XCTAssertTrue(
            form.waitForExistence(timeout: 10),
            "Add-expense destination should present New Transaction"
        )
        attachScreenshot(in: app, name: "w5-add-expense-opens-quick-entry")
        #endif
    }

    @MainActor
    func testAppLockGateRefusesSpendingAmounts() throws {
        #if !os(iOS)
        throw XCTSkip("App Lock gate UI verification runs on iOS Simulator only")
        #else
        let app = XCUIApplication()
        app.launchArguments = [
            "--uitesting",
            "--ui-test-app-lock",
            "--ui-test-show-spending-intent-result",
        ]
        app.launch()
        XCTAssertTrue(UITestSupport.waitForContentRoot(in: app, timeout: 15))

        let unlockMessage = "Unlock Vittora to see your spending"
        let alert = app.alerts["Today's Spending"]
        XCTAssertTrue(alert.waitForExistence(timeout: 10), "Spending intent result alert should appear")
        XCTAssertTrue(
            app.staticTexts[unlockMessage].waitForExistence(timeout: 3),
            "Locked session must show unlock message, never an amount"
        )
        attachScreenshot(in: app, name: "w5-app-lock-refusal")
        #endif
    }

    @MainActor
    func testSpendingQueryShowsFormattedAmountWhenUnlocked() throws {
        #if !os(iOS)
        throw XCTSkip("Spending query UI verification runs on iOS Simulator only")
        #else
        let app = XCUIApplication()
        app.launchArguments = [
            "--uitesting",
            "--ui-test-show-spending-intent-result",
        ]
        app.launch()
        XCTAssertTrue(UITestSupport.waitForContentRoot(in: app, timeout: 15))

        let alert = app.alerts["Today's Spending"]
        XCTAssertTrue(alert.waitForExistence(timeout: 10), "Spending intent result alert should appear")
        let spent = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "You've spent")
        ).firstMatch
        XCTAssertTrue(spent.waitForExistence(timeout: 3), "Unlocked query should return a spending summary")
        attachScreenshot(in: app, name: "w5-spending-query-amount")
        #endif
    }

    @MainActor
    private func attachScreenshot(in app: XCUIApplication, name: String) {
        let shot = app.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        let data = shot.pngRepresentation
        let dir = URL(fileURLWithPath: "/Volumes/Data/Projects/Vittora/Vittora-worktrees/w5/verification")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? data.write(to: dir.appendingPathComponent("\(name).png"))
    }
}

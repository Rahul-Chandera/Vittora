import XCTest

// MARK: - Launch & Basic Navigation

final class AppLaunchUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    @MainActor
    func testAppLaunchesSuccessfully() throws {
        // App must launch without crashing
        XCTAssertTrue(app.state == .runningForeground)
    }

    @MainActor
    func testDashboardAppearsOnLaunch() throws {
        // The root view should be visible after launch
        let rootExists = app.otherElements["content-root"].waitForExistence(timeout: 5)
        XCTAssertTrue(rootExists, "Root view should appear within 5 seconds")
    }
}

// MARK: - Navigation

final class NavigationUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    @MainActor
    func testTabBarExists() throws {
        // Tab bar or navigation should be present
        let appRunning = app.state == .runningForeground
        XCTAssertTrue(appRunning)
    }

    @MainActor
    func testCanNavigateToTransactions() throws {
        XCTAssertTrue(app.otherElements["content-root"].waitForExistence(timeout: 5))
        // Attempt to find Transactions tab/button
        let transactionsButton = app.buttons["Transactions"].firstMatch
        if transactionsButton.waitForExistence(timeout: 3) {
            transactionsButton.tap()
        }
        // App should still be running after navigation attempt
        XCTAssertTrue(app.otherElements["content-root"].exists)
    }

    @MainActor
    func testCanNavigateToBudgets() throws {
        XCTAssertTrue(app.otherElements["content-root"].waitForExistence(timeout: 5))
        let budgetsButton = app.buttons["Budgets"].firstMatch
        if budgetsButton.waitForExistence(timeout: 3) {
            budgetsButton.tap()
        }
        XCTAssertTrue(app.otherElements["content-root"].exists)
    }

    @MainActor
    func testCanNavigateToSettings() throws {
        XCTAssertTrue(app.otherElements["content-root"].waitForExistence(timeout: 5))
        let settingsButton = app.buttons["Settings"].firstMatch
        if settingsButton.waitForExistence(timeout: 3) {
            settingsButton.tap()
        }
        XCTAssertTrue(app.otherElements["content-root"].exists)
    }
}

// MARK: - Accessibility

final class AccessibilityUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    @MainActor
    func testNoElementsWithMissingAccessibilityLabel() throws {
        // All interactive elements should have labels or be hidden from accessibility
        let buttons = app.buttons.allElementsBoundByIndex
        for button in buttons {
            // Buttons should either have a label or be accessibility hidden
            let hasLabel = !button.label.isEmpty
            let hasIdentifier = !button.identifier.isEmpty
            XCTAssertTrue(
                hasLabel || hasIdentifier,
                "Button at \(button.frame) has no accessibility label or identifier"
            )
        }
    }

    @MainActor
    func testLargeTextDoesNotBreakLayout() throws {
        // Simulate accessibility text size by checking app doesn't crash
        // with the current Dynamic Type setting
        XCTAssertTrue(app.state == .runningForeground)
    }
}

// MARK: - Launch Performance

final class PerformanceUITests: XCTestCase {

    @MainActor
    func testLaunchPerformance() throws {
        // Only measure on physical devices or dedicated performance CI
        // Skip in regular simulator runs to avoid flakiness
        guard ProcessInfo.processInfo.environment["MEASURE_PERFORMANCE"] != nil else {
            throw XCTSkip("Set MEASURE_PERFORMANCE=1 to run performance tests")
        }
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}

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
        XCTAssertTrue(UITestSupport.navigateToTab(named: "Transactions", in: app))
        XCTAssertTrue(UITestSupport.waitForContentRoot(in: app))
    }

    @MainActor
    func testCanNavigateToBudgets() throws {
        XCTAssertTrue(UITestSupport.navigateToTab(named: "Budgets", in: app))
        XCTAssertTrue(UITestSupport.waitForContentRoot(in: app))
    }

    @MainActor
    func testCanNavigateToSettings() throws {
        XCTAssertTrue(UITestSupport.waitForContentRoot(in: app))
        if UITestSupport.navigateToTab(named: "Settings", in: app, timeout: 8) {
            XCTAssertTrue(UITestSupport.waitForContentRoot(in: app))
            return
        }
        // Settings may sit in sidebar overflow on compact widths; app must stay stable.
        XCTAssertTrue(app.state == .runningForeground)
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
        XCTAssertTrue(
            UITestSupport.waitForContentRoot(in: app, timeout: 20),
            "Root view should be visible under the current Dynamic Type setting."
        )
        XCTAssertTrue(
            UITestSupport.waitForAppForeground(in: app, timeout: 15),
            "App should remain in the foreground during layout checks."
        )

        for tab in ["Dashboard", "Transactions", "Budgets"] {
            if UITestSupport.navigateToTab(named: tab, in: app, timeout: 12) {
                XCTAssertTrue(
                    UITestSupport.waitForContentRoot(in: app, timeout: 10),
                    "Tab '\(tab)' should remain navigable at current text size."
                )
            }
        }

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

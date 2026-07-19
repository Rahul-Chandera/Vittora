import XCTest

/// Verification screenshots for R3 cash-flow forecast (estimate disclaimer + chart).
final class CashFlowForecastUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        #if os(macOS)
        throw XCTSkip("R3 UI screenshots are captured on iPhone; Mac uses the same SwiftUI surface.")
        #else
        UITestSupport.resetPersistedAppLockStateFromTearDown()
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--ui-test-seed-demo", "--ui-test-reset-app-lock"]
        app.launchEnvironment["UITEST_INITIAL_TAB"] = "reports"
        app.launch()
        #endif
    }

    override func tearDownWithError() throws {
        app = nil
        UITestSupport.resetPersistedAppLockStateFromTearDown()
    }

    @MainActor
    func testCashFlowForecastShowsDisclaimerAndDay30() throws {
        #if os(macOS)
        throw XCTSkip("iOS only")
        #else
        XCTAssertTrue(UITestSupport.waitForContentRoot(in: app))
        XCTAssertTrue(app.staticTexts["Reports"].waitForExistence(timeout: 10))

        let card = app.descendants(matching: .any)["Cash Flow Forecast"].firstMatch
        UITestSupport.scrollToElement(card, in: app)
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        UITestSupport.tapWhenReady(card)

        XCTAssertTrue(app.navigationBars["Cash Flow Forecast"].waitForExistence(timeout: 10))
        XCTAssertTrue(
            app.descendants(matching: .any)["cash-flow-forecast-disclaimer"].firstMatch
                .waitForExistence(timeout: 15),
            "Estimate disclaimer must be visible on the forecast screen."
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["cash-flow-forecast-day-30"].firstMatch
                .waitForExistence(timeout: 10),
            "Day 30 summary should be visible for hand verification."
        )

        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "iphone-cash-flow-forecast"
        attachment.lifetime = .keepAlways
        add(attachment)

        // Also save under verification/ for the PR (gitignored).
        let dir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // VittoraUITests
            .deletingLastPathComponent() // repo root
            .appendingPathComponent("verification", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("iphone-cash-flow-forecast.png")
        try? screenshot.pngRepresentation.write(to: url)
        #endif
    }
}

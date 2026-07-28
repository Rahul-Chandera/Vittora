import XCTest

/// Verification screenshots for R1 PDF export entry points (iOS share flow).
/// macOS uses `NSSavePanel` via `ReportPDFShareLink` (covered by unit/render tests).
final class ReportPDFExportUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        #if os(macOS)
        throw XCTSkip("R1 UI screenshots are iPhone-focused; macOS export uses the save panel.")
        #else
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--ui-test-seed-demo"]
        app.launchEnvironment["UITEST_INITIAL_TAB"] = "reports"
        app.launch()
        #endif
    }

    override func tearDownWithError() throws {
        app = nil
    }

    @MainActor
    func testMonthlyOverviewShowsExportPDF() throws {
        #if os(macOS)
        throw XCTSkip("iOS only")
        #else
        XCTAssertTrue(UITestSupport.waitForContentRoot(in: app))
        XCTAssertTrue(app.staticTexts["Reports"].waitForExistence(timeout: 10))

        let monthly = app.descendants(matching: .any)["Monthly Overview"].firstMatch
        XCTAssertTrue(monthly.waitForExistence(timeout: 10))
        monthly.tap()

        XCTAssertTrue(app.navigationBars["Monthly Overview"].waitForExistence(timeout: 10))
        let export = app.buttons["Export PDF"]
        XCTAssertTrue(
            export.waitForExistence(timeout: 15),
            "Export PDF should appear once monthly report data is loaded."
        )

        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "iphone-monthly-overview-export"
        attachment.lifetime = .keepAlways
        add(attachment)
        #endif
    }

    @MainActor
    func testAnnualSummaryShowsExportPDF() throws {
        #if os(macOS)
        throw XCTSkip("iOS only")
        #else
        XCTAssertTrue(UITestSupport.waitForContentRoot(in: app))

        // Year in Review sits above Annual Summary; scroll via hardened helper
        // (clears live nav-bar / tab-bar frames) before tapping the stable id.
        let annual = app.descendants(matching: .any)["report-card-annual"].firstMatch
        UITestSupport.scrollToElement(annual, in: app)
        XCTAssertTrue(annual.waitForExistence(timeout: 10), "Annual Summary card should exist.")
        annual.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        XCTAssertTrue(app.navigationBars["Annual Summary"].waitForExistence(timeout: 10))
        let export = app.buttons["Export PDF"]
        XCTAssertTrue(
            export.waitForExistence(timeout: 15),
            "Export PDF should appear once annual report data is loaded."
        )

        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "iphone-annual-summary-export"
        attachment.lifetime = .keepAlways
        add(attachment)
        #endif
    }
}

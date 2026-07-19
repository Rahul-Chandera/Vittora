import XCTest

/// Verification screenshots for R3 cash-flow forecast (estimate disclaimer + chart).
final class CashFlowForecastUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        #if os(macOS)
        throw XCTSkip("R3 UI screenshots are captured on iPhone; Mac uses the same SwiftUI surface.")
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
    func testCashFlowForecastShowsDisclaimerAndDay30() throws {
        #if os(macOS)
        throw XCTSkip("iOS only")
        #else
        XCTAssertTrue(UITestSupport.waitForContentRoot(in: app), "Content root should appear")
        XCTAssertTrue(app.staticTexts["Reports"].waitForExistence(timeout: 15))

        // Prefer the stable card identifier over localized label matching.
        let card = app.descendants(matching: .any)["report-card-cashFlowForecast"].firstMatch
        for _ in 0..<8 where !card.exists || !card.isHittable {
            app.swipeUp()
            RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        }
        XCTAssertTrue(card.waitForExistence(timeout: 15), "Cash Flow Forecast card should exist")
        card.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        let disclaimer = app.descendants(matching: .any)["cash-flow-forecast-disclaimer"].firstMatch
        let day30 = app.descendants(matching: .any)["cash-flow-forecast-day-30"].firstMatch
        let deadline = Date().addingTimeInterval(25)
        while Date() < deadline, !disclaimer.exists {
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }

        if !disclaimer.exists {
            let debug = XCUIScreen.main.screenshot()
            let attachment = XCTAttachment(screenshot: debug)
            attachment.name = "iphone-cash-flow-forecast-debug"
            attachment.lifetime = .keepAlways
            add(attachment)
            let dir = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("verification", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try? debug.pngRepresentation.write(
                to: dir.appendingPathComponent("iphone-cash-flow-forecast-debug.png")
            )
        }

        XCTAssertTrue(
            disclaimer.exists,
            "Estimate disclaimer must be visible on the forecast screen. Debug hierarchy: \(app.debugDescription.prefix(2000))"
        )
        XCTAssertTrue(
            day30.waitForExistence(timeout: 10),
            "Day 30 summary should be visible for hand verification."
        )

        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "iphone-cash-flow-forecast"
        attachment.lifetime = .keepAlways
        add(attachment)

        let dir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("verification", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("iphone-cash-flow-forecast.png")
        try screenshot.pngRepresentation.write(to: url)
        #endif
    }
}

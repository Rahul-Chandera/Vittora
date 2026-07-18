import XCTest

/// Verification-only UI coverage for R2 Subscription Audit (demo dataset).
final class SubscriptionAuditUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--ui-test-seed-demo"]
        app.launchEnvironment["UITEST_INITIAL_TAB"] = "reports"
        app.launchEnvironment["UITEST_DEMO_REGION"] = "US"
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    @MainActor
    func testSubscriptionAuditShowsNetflixFromDemo() throws {
        XCTAssertTrue(UITestSupport.waitForContentRoot(in: app), "Reports should load")
        XCTAssertTrue(UITestSupport.navigateToTab(named: "Reports", in: app) || app.navigationBars["Reports"].waitForExistence(timeout: 5))

        let card = app.staticTexts["Subscription Audit"]
        UITestSupport.scrollToElement(card, in: app)
        UITestSupport.tapWhenReady(card, timeout: 10)

        XCTAssertTrue(
            app.navigationBars["Subscription Audit"].waitForExistence(timeout: 10),
            "Subscription Audit report should open"
        )

        let netflix = app.staticTexts["Netflix"]
        UITestSupport.scrollToElement(netflix, in: app)
        XCTAssertTrue(netflix.waitForExistence(timeout: 10), "Demo Netflix rule should appear")

        writeScreenshot(named: "iphone-subscription-audit")
    }

    @MainActor
    private func writeScreenshot(named name: String) {
        let data = app.screenshot().pngRepresentation
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let folder = repoRoot.appendingPathComponent("verification", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent("\(name).png")
        try? data.write(to: url)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

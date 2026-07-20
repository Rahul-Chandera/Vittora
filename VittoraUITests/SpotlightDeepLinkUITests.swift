import XCTest

/// P2: Spotlight deep-link → transaction detail, gated by App Lock like W4.
final class SpotlightDeepLinkUITests: XCTestCase {

    /// Fixed ID from `UITestDataSeeder.seedTransactionScenarioIfNeeded` (Coffee Run).
    private static let coffeeTransactionID = "C0FFEE01-A24C-4C32-A4BE-53C6D9951D01"

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDownWithError() throws {
        UITestSupport.resetPersistedAppLockStateFromTearDown()
        app = nil
        try super.tearDownWithError()
    }

    @MainActor
    func testSpotlightDeepLinkOpensTransactionDetail() throws {
        #if !os(iOS)
        throw XCTSkip("Spotlight deep link UI tests run on iOS Simulator only")
        #else
        app.launchArguments = [
            "--uitesting",
            "--ui-test-reset-app-lock",
            "--ui-test-seed-transactions",
            "--ui-test-open-transaction=\(Self.coffeeTransactionID)",
        ]
        app.launch()
        XCTAssertTrue(UITestSupport.waitForContentRoot(in: app, timeout: 15))

        let detail = app.descendants(matching: .any)["transaction-detail-root"]
        XCTAssertTrue(
            detail.waitForExistence(timeout: 12),
            "Spotlight deep link should open transaction detail"
        )
        XCTAssertTrue(
            app.staticTexts["Coffee Run"].waitForExistence(timeout: 5)
                || app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Coffee")).firstMatch.waitForExistence(timeout: 3)
        )

        attachScreenshot(name: "spotlight-deeplink-detail")
        #endif
    }

    @MainActor
    func testAppLockBlocksSpotlightDeepLinkUntilUnlock() throws {
        #if !os(iOS)
        throw XCTSkip("Spotlight deep link UI tests run on iOS Simulator only")
        #else
        app.launchArguments = [
            "--uitesting",
            "--ui-test-app-lock",
            "--ui-test-seed-transactions",
            "--ui-test-open-transaction=\(Self.coffeeTransactionID)",
        ]
        app.launch()
        XCTAssertTrue(UITestSupport.waitForContentRoot(in: app, timeout: 15))

        XCUIDevice.shared.press(.home)
        sleep(2)
        app.activate()

        let lockRoot = app.otherElements["app-lock-root"]
        let lockTitle = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Locked")
        ).firstMatch
        let lockAppeared = lockRoot.waitForExistence(timeout: 10)
            || lockTitle.waitForExistence(timeout: 2)
        XCTAssertTrue(lockAppeared, "App lock screen should appear after background")
        XCTAssertFalse(
            app.descendants(matching: .any)["transaction-detail-root"].exists,
            "Transaction detail must not present while locked"
        )

        attachScreenshot(name: "spotlight-deeplink-app-lock-gated")
        #endif
    }

    @MainActor
    private func attachScreenshot(name: String) {
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        let data = shot.pngRepresentation
        let dir = URL(fileURLWithPath: "/Volumes/Data/Projects/Vittora/Vittora-worktrees/p2/verification")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? data.write(to: dir.appendingPathComponent("\(name).png"))
    }
}

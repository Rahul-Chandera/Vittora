import XCTest

/// F3 gating, end to end. A lock screen whose button goes nowhere is worse than no gate,
/// so the upgrade route is walked, not just asserted to exist.
final class ProGatingUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        #if os(macOS)
        throw XCTSkip("Pro gating UI coverage runs on iPhone Simulator.")
        #else
        app = XCUIApplication()
        #endif
    }

    override func tearDownWithError() throws {
        #if !os(macOS)
        app?.terminate()
        #endif
        app = nil
    }

    #if !os(macOS)
    @MainActor
    private func launchReports(pro: Bool) {
        app.launchArguments =
            ["--uitesting", "--ui-test-seed-demo", "--ui-test-reset-app-lock"]
            + (pro ? ["--ui-test-pro"] : [])
        app.launchEnvironment["UITEST_INITIAL_TAB"] = "reports"
        app.launch()
        XCTAssertTrue(UITestSupport.waitForAppForeground(in: app))
        XCTAssertTrue(app.navigationBars["Reports"].waitForExistence(timeout: 20))
    }

    @MainActor
    private func openEmergencyFundCard() {
        let card = app.descendants(matching: .any)["report-card-emergencyFund"].firstMatch
        UITestSupport.scrollToElement(card, in: app)
        XCTAssertTrue(card.waitForExistence(timeout: 20), "Emergency Fund report card should exist.")
        card.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }
    #endif

    /// Catches the regression that makes gating worthless: a locked surface with no
    /// reachable paywall, which is also an App Review 3.1.1 problem.
    @MainActor
    func testFreeUserHitsTheLockAndCanReachThePaywall() throws {
        #if os(macOS)
        throw XCTSkip("iOS only")
        #else
        launchReports(pro: false)
        openEmergencyFundCard()

        let upgrade = app.buttons["pro-lock-upgrade-button"].firstMatch
        XCTAssertTrue(
            upgrade.waitForExistence(timeout: 20),
            "A free user opening a Pro report should get the lock screen."
        )
        UITestSupport.tapWhenReady(upgrade, timeout: 15)
        XCTAssertTrue(
            app.navigationBars["Vittora Pro"].waitForExistence(timeout: 20),
            "The lock screen's upgrade button must actually open the paywall."
        )
        #endif
    }

    /// Catches a regression where the Pro entitlement stops unlocking anything — which
    /// would leave every --ui-test-pro audit silently sampling a lock screen instead.
    @MainActor
    func testProUserOpensTheReport() throws {
        #if os(macOS)
        throw XCTSkip("iOS only")
        #else
        launchReports(pro: true)
        openEmergencyFundCard()

        XCTAssertTrue(
            app.navigationBars["Emergency Fund"].waitForExistence(timeout: 20),
            "A Pro user should reach the report itself."
        )
        XCTAssertFalse(
            app.buttons["pro-lock-upgrade-button"].exists,
            "A Pro user must never see the lock screen."
        )
        #endif
    }
}

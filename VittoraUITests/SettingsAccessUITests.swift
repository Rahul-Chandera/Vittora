import XCTest

/// Settings must be reachable from the main navigation on every idiom.
/// Regression guard for the iPad bug where a header-less TabSection rendered
/// as an empty disclosure — no sidebar row, no top-bar item — leaving
/// Settings unreachable in both orientations.
final class SettingsAccessUITests: XCTestCase {

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
    func testSettingsIsReachableFromMainNavigation() throws {
        XCTAssertTrue(
            UITestSupport.waitForContentRoot(in: app, timeout: 20),
            "App shell should be visible."
        )

        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad {
            // Regular width: the Settings tab lives in the "General" section
            // of the sidebar/top tab bar. The section header must exist —
            // without it the tab is invisible.
            let generalSection = app.buttons["General"].firstMatch
            let settingsTab = app.buttons["Settings"].firstMatch
            XCTAssertTrue(
                generalSection.waitForExistence(timeout: 10) || settingsTab.waitForExistence(timeout: 5),
                "The Settings tab (or its General section) should be visible in the iPad tab bar."
            )
            UITestSupport.tapWhenReady(
                generalSection.exists ? generalSection : settingsTab,
                timeout: 10
            )
        } else {
            // Compact width: Settings lives in the More hub.
            let moreTab = app.tabBars.buttons[String(localized: "More")].firstMatch
            XCTAssertTrue(moreTab.waitForExistence(timeout: 10), "The More tab should exist on iPhone.")
            UITestSupport.tapWhenReady(moreTab, timeout: 10)

            let settingsRow = app.buttons["Settings"].firstMatch
            XCTAssertTrue(settingsRow.waitForExistence(timeout: 10), "More hub should list Settings.")
            UITestSupport.tapWhenReady(settingsRow, timeout: 10)
        }
        #endif

        XCTAssertTrue(
            app.staticTexts["Settings"].firstMatch.waitForExistence(timeout: 10),
            "The Settings screen should open from the main navigation."
        )
    }
}

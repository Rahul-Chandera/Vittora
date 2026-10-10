import XCTest

final class QuickEntryPresentationUITests: XCTestCase {

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
    func testFloatingButtonOpensQuickEntry() throws {
        XCTAssertTrue(
            UITestSupport.waitForContentRoot(in: app, timeout: 20),
            "App shell should be visible."
        )

        let floating = app.buttons["quick-entry-floating-button"]
        XCTAssertTrue(floating.waitForExistence(timeout: 15), "Floating add button should be on the dashboard.")
        UITestSupport.tapWhenReady(floating, timeout: 10)

        XCTAssertTrue(
            app.buttons["Save Transaction"].waitForExistence(timeout: 10),
            "Quick entry should open from the floating button."
        )

        // Quick entry must be a sheet at every width, never a full-screen cover:
        // on iPhone Duo the size class flips when the device folds, and switching
        // presentation on it dismissed the form mid-entry. The underlying UI stays
        // in the accessibility hierarchy under a sheet but is removed by a cover.
        XCTAssertTrue(
            app.buttons["quick-entry-floating-button"].exists,
            "Quick entry should present as a sheet (dashboard still in hierarchy)."
        )
    }
}

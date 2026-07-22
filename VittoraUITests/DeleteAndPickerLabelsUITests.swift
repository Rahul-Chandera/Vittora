import XCTest

final class DeleteAndPickerLabelsUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = [
            "--uitesting",
            "--ui-test-reset-app-lock",
            "--ui-test-seed-transactions"
        ]
        app.launchEnvironment["UITEST_INITIAL_TAB"] = "transactions"
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    @MainActor
    func testBlockedAccountDeleteShowsAlertAndArchivesInstead() throws {
        XCTAssertTrue(
            app.descendants(matching: .any)["transaction-row-coffee-run"].waitForExistence(timeout: 20),
            "The seeded transaction must exist before testing its account's blocked deletion."
        )
        openSettingsDestination("settings-manage-accounts")

        let accountRow = app.descendants(matching: .any)["account-row-UI Test Checking"]
        UITestSupport.scrollToElement(accountRow, in: app)
        XCTAssertTrue(accountRow.waitForExistence(timeout: 20), "The seeded account should be visible.")

        accountRow.swipeLeft()
        UITestSupport.tapWhenReady(app.buttons["Delete"].firstMatch)
        UITestSupport.tapWhenReady(app.alerts["Delete Account"].buttons["Delete"])

        let errorAlert = app.alerts["Error"]
        XCTAssertTrue(
            errorAlert.waitForExistence(timeout: 10),
            "A blocked account deletion must show a visible error alert."
        )
        XCTAssertTrue(
            errorAlert.buttons["Archive Instead"].exists,
            "The blocked-delete alert must offer the archive action."
        )
        try saveScreenshot(named: "blocked-delete-alert")

        UITestSupport.tapWhenReady(errorAlert.buttons["Archive Instead"])
        XCTAssertTrue(
            UITestSupport.waitForDisappearance(accountRow, timeout: 15),
            "Archive Instead should archive and remove the account from the active list."
        )
    }

    @MainActor
    func testRecurringPickerLabelsShowSelectedNames() throws {
        XCTAssertTrue(
            app.descendants(matching: .any)["transaction-row-coffee-run"].waitForExistence(timeout: 20),
            "The picker data must be seeded before opening the recurring form."
        )
        openSettingsDestination("settings-manage-recurring")
        let rule = app.descendants(matching: .any)[
            "recurring-row-DB8D2197-FD80-4A39-8EB7-28D1AB42C901"
        ]
        UITestSupport.tapWhenReady(rule, timeout: 20)
        UITestSupport.tapWhenReady(app.buttons["recurring-edit-button"], timeout: 15)

        XCTAssertEqual(app.buttons["recurring-account-picker"].label, "UI Test Checking")
        XCTAssertEqual(app.buttons["recurring-category-picker"].label, "Groceries")
        XCTAssertEqual(app.buttons["recurring-payee-picker"].label, "UI Test Merchant")

        try saveScreenshot(named: "recurring-picker-labels")
    }

    @MainActor
    private func openSettingsDestination(_ identifier: String) {
        XCTAssertTrue(UITestSupport.waitForContentRoot(in: app), "The app shell should be visible.")
        let destination = app.descendants(matching: .any)[identifier]
        if !destination.exists {
            if app.tabBars.buttons["More"].exists {
                UITestSupport.tapWhenReady(app.tabBars.buttons["More"])
            }
            UITestSupport.tapWhenReady(app.buttons["Settings"].firstMatch, timeout: 15)
        }
        UITestSupport.scrollToElement(destination, in: app)
        UITestSupport.tapWhenReady(destination, timeout: 20)
    }

    @MainActor
    private func saveScreenshot(named name: String) throws {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        let directory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("verification", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try screenshot.pngRepresentation.write(to: directory.appendingPathComponent("\(name).png"))
    }
}

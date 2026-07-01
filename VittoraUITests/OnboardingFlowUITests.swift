import XCTest

final class OnboardingFlowUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--ui-test-onboarding"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    @MainActor
    func testCanCompleteOnboardingAndReachDashboard() throws {
        XCTAssertTrue(
            app.otherElements["onboarding-root"].waitForExistence(timeout: 10),
            "Onboarding root should appear in onboarding UI test mode."
        )
        XCTAssertTrue(
            app.staticTexts["onboarding-welcome-title"].waitForExistence(timeout: 5),
            "Welcome step should be visible."
        )

        tapNext()

        let currencyButton = app.buttons["onboarding-currency-USD"]
        XCTAssertTrue(currencyButton.waitForExistence(timeout: 5))
        currencyButton.tap()
        tapNext()

        let nameField = app.textFields["onboarding-name-field"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("Taylor\n")
        tapNext()

        let bankAccountType = app.buttons["onboarding-account-type-bank"]
        if bankAccountType.waitForExistence(timeout: 3) {
            bankAccountType.tap()
            tapNext()
        }

        let accountNameField = app.textFields["onboarding-account-name-field"]
        XCTAssertTrue(accountNameField.waitForExistence(timeout: 5))
        accountNameField.tap()
        accountNameField.typeText("Daily Checking")

        let openingBalanceField = app.textFields["onboarding-opening-balance-field"]
        XCTAssertTrue(openingBalanceField.waitForExistence(timeout: 5))
        openingBalanceField.tap()
        openingBalanceField.typeText("1000")
        dismissKeyboardIfNeeded()

        tapNextWhenEnabled(timeout: 15)

        XCTAssertTrue(
            waitForOnboardingStep("onboarding-notifications-step", timeout: 20),
            "Should advance to the notifications step after account setup."
        )
        tapNext()

        XCTAssertTrue(
            waitForOnboardingStep("onboarding-complete-step", timeout: 15),
            "The review step should appear before finishing onboarding."
        )
        XCTAssertTrue(
            app.staticTexts["onboarding-done-title"].waitForExistence(timeout: 5),
            "Done title should be visible on the review step."
        )

        tapNext()

        XCTAssertFalse(
            app.buttons["onboarding-next-button"].waitForExistence(timeout: 2),
            "The onboarding CTA should be dismissed after finishing the flow."
        )
        XCTAssertTrue(
            app.tabBars.buttons["Transactions"].waitForExistence(timeout: 10),
            "The main app tab bar should appear after onboarding completes."
        )
    }

    @MainActor
    private func tapNext() {
        let nextButton = app.buttons["onboarding-next-button"]
        XCTAssertTrue(nextButton.waitForExistence(timeout: 5))
        nextButton.tap()
    }

    @MainActor
    private func tapNextWhenEnabled(timeout: TimeInterval) {
        let nextButton = app.buttons["onboarding-next-button"]
        let enabledExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isEnabled == true"),
            object: nextButton
        )
        XCTAssertEqual(
            XCTWaiter().wait(for: [enabledExpectation], timeout: timeout),
            .completed,
            "Next button should become enabled before advancing."
        )
        nextButton.tap()
    }

    @MainActor
    private func waitForOnboardingStep(_ identifier: String, timeout: TimeInterval) -> Bool {
        app.descendants(matching: .any)[identifier].waitForExistence(timeout: timeout)
    }

    @MainActor
    private func dismissKeyboardIfNeeded() {
        let toolbarDone = app.toolbars.buttons["Done"]
        if toolbarDone.waitForExistence(timeout: 2) {
            toolbarDone.tap()
        }
    }
}

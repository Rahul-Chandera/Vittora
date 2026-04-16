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
        let nextButton = app.buttons["onboarding-next-button"]
        XCTAssertTrue(nextButton.waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.staticTexts["onboarding-welcome-title"].waitForExistence(timeout: 5),
            "Onboarding should be visible in onboarding UI test mode."
        )

        nextButton.tap()

        let currencyButton = app.buttons["onboarding-currency-USD"]
        XCTAssertTrue(currencyButton.waitForExistence(timeout: 5))
        currencyButton.tap()
        nextButton.tap()

        let nameField = app.textFields["onboarding-name-field"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("Taylor\n")
        nextButton.tap()

        let accountNameField = app.textFields["onboarding-account-name-field"]
        XCTAssertTrue(accountNameField.waitForExistence(timeout: 5))
        accountNameField.tap()
        accountNameField.typeText("Daily Checking\n")
        nextButton.tap()

        let completionStepExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", "Start Tracking"),
            object: nextButton
        )
        XCTAssertEqual(
            XCTWaiter().wait(for: [completionStepExpectation], timeout: 5),
            .completed,
            "The review step should appear before finishing onboarding."
        )

        nextButton.tap()

        XCTAssertFalse(
            nextButton.waitForExistence(timeout: 1),
            "The onboarding CTA should be dismissed after finishing the flow."
        )
        XCTAssertTrue(
            app.tabBars.buttons["Transactions"].waitForExistence(timeout: 5),
            "The main app tab bar should appear after onboarding completes."
        )
    }
}

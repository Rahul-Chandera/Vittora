import XCTest

final class VittoraUITestsLaunchTests: XCTestCase {

    // Disabled: running for every UI configuration causes flaky failures
    // in simulator environments without a full display context.
    override class var runsForEachTargetApplicationUIConfiguration: Bool { false }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()

        XCTAssertTrue(
            app.state == .runningForeground,
            "App should be running in foreground after launch"
        )
        XCTAssertTrue(
            app.otherElements["content-root"].waitForExistence(timeout: 5),
            "Root view should appear before we capture the launch screenshot"
        )

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

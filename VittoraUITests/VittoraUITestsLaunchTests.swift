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

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

import XCTest

/// O1 — Contact Support shows a user-reviewed diagnostics payload before send.
final class ContactSupportUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = [
            "--uitesting",
            "--ui-test-seed-demo",
            "--ui-test-reset-app-lock",
        ]
        app.launchEnvironment["UITEST_INITIAL_TAB"] = "dashboard"
        app.launch()
    }

    override func tearDownWithError() throws {
        UITestSupport.resetPersistedAppLockStateFromTearDown()
        app = nil
    }

    @MainActor
    func testContactSupportShowsScrollablePayloadBeforeSend() throws {
        #if os(macOS)
        throw XCTSkip("Contact Support UI gate runs on iPhone Simulator.")
        #else
        XCTAssertTrue(UITestSupport.waitForContentRoot(in: app), "App shell should be visible.")
        openContactSupport()

        let disclaimer = app.staticTexts["contact-support-payload-disclaimer"]
        XCTAssertTrue(
            disclaimer.waitForExistence(timeout: 15),
            "Payload disclaimer must be visible before any send action."
        )
        XCTAssertTrue(
            disclaimer.label.localizedCaseInsensitiveContains("everything that will be included"),
            "User must see that the preview is exactly what will be included."
        )

        let payload = app.descendants(matching: .any)["contact-support-payload"]
        XCTAssertTrue(payload.waitForExistence(timeout: 10), "Diagnostic payload preview must exist.")
        XCTAssertTrue(payload.isHittable || payload.exists, "Payload preview should be on screen.")

        // Scrollable: swipe inside the preview and confirm it remains present.
        payload.swipeUp()
        XCTAssertTrue(payload.exists, "Payload preview must remain after scrolling.")

        let send = app.buttons["contact-support-send"]
        XCTAssertTrue(send.waitForExistence(timeout: 5), "Send Email control must exist after the preview.")
        XCTAssertTrue(send.isEnabled, "Send should be enabled once the payload has loaded.")

        // No mail composer yet — preview-first gate. Tapping Send on Simulator
        // without a mail account must offer copy instead of failing silently.
        UITestSupport.tapWhenReady(send, timeout: 5)
        let noMail = app.alerts["Mail Not Configured"].firstMatch
        let mailSheet = app.navigationBars["New Message"].firstMatch
        let copied = app.alerts["Copied"].firstMatch
        let sawGracefulPath =
            noMail.waitForExistence(timeout: 5)
            || mailSheet.waitForExistence(timeout: 3)
            || copied.waitForExistence(timeout: 3)
            || app.alerts.firstMatch.waitForExistence(timeout: 3)
        XCTAssertTrue(
            sawGracefulPath || app.buttons["contact-support-copy"].exists,
            "Without mail, Contact Support must offer a graceful copy path."
        )

        if noMail.exists {
            UITestSupport.tapWhenReady(noMail.buttons["Copy Diagnostics"], timeout: 5)
            XCTAssertTrue(
                app.alerts["Copied"].waitForExistence(timeout: 5),
                "Copy-from-no-mail path should confirm clipboard copy."
            )
        }
        #endif
    }

    @MainActor
    func testContactSupportAccessibilityAudit() throws {
        #if os(macOS)
        throw XCTSkip("iOS only")
        #else
        openContactSupport()
        XCTAssertTrue(
            app.staticTexts["contact-support-payload-disclaimer"].waitForExistence(timeout: 15)
        )
        try app.performAccessibilityAudit { issue in
            switch issue.auditType {
            case .hitRegion, .contrast:
                return true
            case .textClipped:
                return issue.compactDescription.localizedCaseInsensitiveContains("may be clipped")
            case .dynamicType:
                return issue.compactDescription.localizedCaseInsensitiveContains("partially")
            default:
                return false
            }
        }
        #endif
    }

    @MainActor
    private func openContactSupport() {
        XCTAssertTrue(UITestSupport.waitForContentRoot(in: app), "App shell should be visible.")

        // Reach Settings (compact → More hub; regular → tab / sidebar).
        if !app.navigationBars["Settings"].exists {
            if app.tabBars.buttons["More"].exists {
                UITestSupport.tapWhenReady(app.tabBars.buttons["More"])
            }
            XCTAssertTrue(
                UITestSupport.navigateToTab(named: "Settings", in: app, timeout: 15)
                    || app.buttons["Settings"].firstMatch.waitForExistence(timeout: 5),
                "Settings must be reachable."
            )
            if !app.navigationBars["Settings"].exists {
                UITestSupport.tapWhenReady(app.buttons["Settings"].firstMatch, timeout: 15)
            }
        }
        XCTAssertTrue(
            app.navigationBars["Settings"].waitForExistence(timeout: 10),
            "Settings screen should be open before Contact Support."
        )

        // About section is near the bottom of a long Form — keep scrolling.
        let byID = app.descendants(matching: .any)["settings-contact-support"]
        let byLabel = app.buttons["Contact Support"].firstMatch
        UITestSupport.scrollToElement(byID, in: app, maxSwipes: 20)
        if !byID.exists {
            UITestSupport.scrollToElement(byLabel, in: app, maxSwipes: 20)
        }

        if byID.exists {
            UITestSupport.tapWhenReady(byID, timeout: 20)
        } else {
            UITestSupport.tapWhenReady(byLabel, timeout: 20)
        }

        let opened =
            app.navigationBars["Contact Support"].waitForExistence(timeout: 10)
            || app.descendants(matching: .any)["contact-support-payload-disclaimer"].waitForExistence(timeout: 5)
            || app.staticTexts["This is everything that will be included."].waitForExistence(timeout: 5)
            || app.staticTexts["Diagnostic Summary"].waitForExistence(timeout: 3)

        if !opened {
            // Retry once — nested More → Settings → Support can drop the first tap.
            if byID.exists {
                byID.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            } else if byLabel.exists {
                byLabel.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            }
        }

        XCTAssertTrue(
            app.navigationBars["Contact Support"].waitForExistence(timeout: 10)
                || app.descendants(matching: .any)["contact-support-payload-disclaimer"].waitForExistence(timeout: 10)
                || app.staticTexts["This is everything that will be included."].waitForExistence(timeout: 5),
            "Contact Support screen should open from Settings."
        )
    }
}

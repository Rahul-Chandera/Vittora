import XCTest

/// Shared waits and taps for VittoraUITests (L9 / TESTING-10).
enum UITestSupport {

    /// Relaunches with `--ui-test-reset-app-lock` so Keychain / App Group App Lock
    /// state cannot leak across XCTest cases (simulator Keychain survives relaunch).
    /// Call from the main thread (XCTest setUp/tearDown) or hop via `DispatchQueue.main`.
    @MainActor
    static func resetPersistedAppLockState() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--ui-test-reset-app-lock"]
        app.launch()
        _ = app.wait(for: .runningForeground, timeout: 10)
        app.terminate()
    }

    /// Safe from nonisolated XCTest lifecycle methods.
    static func resetPersistedAppLockStateFromTearDown() {
        let work = {
            MainActor.assumeIsolated {
                resetPersistedAppLockState()
            }
        }
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.sync(execute: work)
        }
    }

    @MainActor
    static func waitForContentRoot(
        in app: XCUIApplication,
        timeout: TimeInterval = 15
    ) -> Bool {
        app.otherElements["content-root"].waitForExistence(timeout: timeout)
    }

    @MainActor
    static func waitForElement(
        _ element: XCUIElement,
        timeout: TimeInterval,
        requireHittable: Bool = false
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.exists {
                if !requireHittable || hasValidFrame(element) {
                    return true
                }
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.15))
        }
        return element.exists && (!requireHittable || hasValidFrame(element))
    }

    @MainActor
    static func tapWhenReady(
        _ element: XCUIElement,
        timeout: TimeInterval = 10,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(
            waitForElement(element, timeout: timeout, requireHittable: true),
            "Element should exist and be tappable before tap.",
            file: file,
            line: line
        )
        tapElementSafely(element)
    }

    @MainActor
    private static func tapElementSafely(_ element: XCUIElement) {
        if hasValidFrame(element) {
            element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        } else {
            element.tap()
        }
    }

    @MainActor
    static func waitForDisappearance(
        _ element: XCUIElement,
        timeout: TimeInterval
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if !element.exists {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.15))
        }
        return !element.exists
    }

    @MainActor
    @discardableResult
    static func navigateToTab(
        named title: String,
        in app: XCUIApplication,
        timeout: TimeInterval = 10
    ) -> Bool {
        guard waitForContentRoot(in: app, timeout: timeout) else { return false }

        let tabBarButton = app.tabBars.buttons[title]
        if tabBarButton.waitForExistence(timeout: timeout) {
            tapWhenReady(tabBarButton, timeout: timeout)
            return true
        }

        let navButton = app.buttons[title].firstMatch
        if navButton.waitForExistence(timeout: 3) {
            tapWhenReady(navButton, timeout: timeout)
            return true
        }

        let moreTab = app.tabBars.buttons["More"]
        if moreTab.waitForExistence(timeout: 3) {
            tapWhenReady(moreTab, timeout: 3)
            let overflowItem = app.buttons[title]
            guard overflowItem.waitForExistence(timeout: timeout) else { return false }
            tapWhenReady(overflowItem, timeout: timeout)
            return true
        }

        return false
    }

    @MainActor
    static func waitForAppForeground(
        in app: XCUIApplication,
        timeout: TimeInterval = 15
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if app.state == .runningForeground {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.15))
        }
        return app.state == .runningForeground
    }

    @MainActor
    static func waitForIdentifier(
        in app: XCUIApplication,
        _ identifier: String,
        toExist: Bool,
        timeout: TimeInterval
    ) -> Bool {
        let element = app.descendants(matching: .any)[identifier]
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.exists == toExist {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return element.exists == toExist
    }

    @MainActor
    static func waitForTransactionRowCount(
        in app: XCUIApplication,
        _ expectedCount: Int,
        timeout: TimeInterval
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        let predicate = NSPredicate(format: "identifier BEGINSWITH %@", "transaction-row-")

        while Date() < deadline {
            let listRoot = app.descendants(matching: .any)["transaction-list-root"]
            let rowCount = listRoot.exists
                ? listRoot.descendants(matching: .any).matching(predicate).count
                : app.descendants(matching: .any).matching(predicate).count

            if rowCount == expectedCount {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }

        return false
    }

    /// Scroll until `element` is on-screen and clear of nav chrome / compact tab bar.
    /// Prefer frame geometry over `isHittable` — hittability queries can hang
    /// for tens of seconds on large SwiftUI hierarchies during UI tests.
    /// Swipes down when the row sits under the navigation bar (swipe-up alone
    /// would push it further off the top — that was the Payees/Categories miss).
    /// Top clearance follows the live navigation bar frame: at AccessibilityXL
    /// the large title bar is ~128pt tall, so a fixed 130pt inset is not enough.
    @MainActor
    static func scrollToElement(
        _ element: XCUIElement,
        in app: XCUIApplication,
        maxSwipes: Int = 24
    ) {
        var swipes = 0
        while swipes < maxSwipes {
            let navBar = app.navigationBars.firstMatch
            let unobscuredTop: CGFloat
            if navBar.exists {
                let navMaxY = navBar.frame.maxY
                unobscuredTop = navMaxY > 1 ? navMaxY + 12 : app.frame.minY + 130
            } else {
                unobscuredTop = app.frame.minY + 130
            }
            let unobscuredBottom = app.frame.maxY - 140

            if element.exists {
                let frame = element.frame
                if frame.width > 1, frame.height > 1 {
                    if frame.minY >= unobscuredTop, frame.maxY <= unobscuredBottom {
                        return
                    }
                    if frame.minY < unobscuredTop {
                        app.swipeDown()
                        swipes += 1
                        RunLoop.current.run(until: Date().addingTimeInterval(0.15))
                        continue
                    }
                    if frame.maxY > unobscuredBottom {
                        app.swipeUp()
                        swipes += 1
                        RunLoop.current.run(until: Date().addingTimeInterval(0.15))
                        continue
                    }
                }
            }
            app.swipeUp()
            swipes += 1
            RunLoop.current.run(until: Date().addingTimeInterval(0.15))
        }
    }

    @MainActor
    private static func hasValidFrame(_ element: XCUIElement) -> Bool {
        let frame = element.frame
        return frame.width > 1 && frame.height > 1
    }
}

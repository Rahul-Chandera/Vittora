import StoreKitTest
import XCTest

/// Captures the paywall for the App Store Connect subscription review screenshot.
///
/// Config-file driven, exactly like `StoreGalleryUITests`: skipped when the file is absent,
/// so a normal `make test` run never captures anything. Driven by
/// `Scripts/store/capture_paywall_shot.sh`.
///
/// The `SKTestSession` is what makes this possible at all. `simctl` cannot apply a StoreKit
/// configuration and `xcodebuild` ignores the scheme's, so a paywall captured any other way
/// shows the "products unavailable" state instead of the plans. A UI test runs the app in a
/// separate process, where the session configures the device rather than the test process.
final class PaywallShotUITests: XCTestCase {

    private struct Config: Decodable {
        let outputDirectory: String
        let locale: String
        let appleLocale: String
        let region: String
    }

    private static var configURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()      // VittoraUITests
            .deletingLastPathComponent()      // repo root
            .appendingPathComponent(".build/paywall-shot-config.json")
    }

    private static var storeKitConfigurationURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Vittora.storekit")
    }

    @MainActor
    func testCapturePaywall() throws {
        #if os(macOS)
        throw XCTSkip("Driven per platform by the capture script.")
        #else
        guard let data = try? Data(contentsOf: Self.configURL) else {
            throw XCTSkip("No paywall-shot config; run Scripts/store/capture_paywall_shot.sh.")
        }
        let config = try JSONDecoder().decode(Config.self, from: data)
        let outDir = URL(fileURLWithPath: config.outputDirectory)
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

        let session = try SKTestSession(contentsOf: Self.storeKitConfigurationURL)
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true

        let app = XCUIApplication()
        app.launchArguments = [
            "--uitesting", "--ui-test-seed-demo", "--ui-test-reset-app-lock",
            "-AppleLocale", config.appleLocale,
            "-AppleLanguages", "(\(config.locale))",
        ]
        app.launchEnvironment["UITEST_INITIAL_TAB"] = "reports"
        app.launchEnvironment["UITEST_DEMO_REGION"] = config.region
        app.launch()
        XCTAssertTrue(UITestSupport.waitForAppForeground(in: app))

        // Same route ProGatingUITests walks: a Pro report gives the lock, the lock opens
        // the paywall. There is no paywall deep link.
        let card = app.descendants(matching: .any)["report-card-emergencyFund"].firstMatch
        UITestSupport.scrollToElement(card, in: app)
        XCTAssertTrue(card.waitForExistence(timeout: 20))
        card.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        UITestSupport.tapWhenReady(app.buttons["pro-lock-upgrade-button"].firstMatch, timeout: 20)
        XCTAssertTrue(app.navigationBars["Vittora Pro"].waitForExistence(timeout: 20))

        // The whole point of the session: without it this is the unavailable state, and the
        // screenshot would show an error where App Review expects the plans and prices.
        let annual = app.descendants(matching: .any)["paywall-plan-com.enerjiktech.vittora.pro.annual"].firstMatch
        XCTAssertTrue(annual.waitForExistence(timeout: 30), "Plans must load, or the shot is worthless.")
        XCTAssertFalse(app.descendants(matching: .any)["paywall-products-unavailable"].firstMatch.exists)

        // Let the price text settle before sampling pixels.
        RunLoop.current.run(until: Date().addingTimeInterval(1.5))

        let shot = XCUIScreen.main.screenshot()
        let destination = outDir.appendingPathComponent("paywall.png")
        try shot.pngRepresentation.write(to: destination)
        print("PAYWALL SHOT WRITTEN: \(destination.path)")
        #endif
    }
}

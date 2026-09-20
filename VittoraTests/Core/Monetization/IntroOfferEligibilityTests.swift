import Foundation
import StoreKit
import StoreKitTest
import Testing
@testable import Vittora

/// The intro-offer *eligible* path, which nothing else covers.
///
/// Every other check in the suite exercises the "no trial" direction, because `xcodebuild`
/// ignores the scheme's `StoreKitConfigurationFileReference` — under `make test` the process
/// has no StoreKit configuration and `Product.products(for:)` returns nothing. `SKTestSession`
/// builds its own session from the file directly, so it does not depend on the scheme at all.
///
/// This matters beyond coverage: showing "7 days free" to an account that has already used the
/// trial is Guideline 3.1.2 exposure, and the eligible direction had never been run anywhere.
///
/// The opposite direction — an account that has consumed the trial — is still not covered.
/// `SKTestSession.buyProduct` does record the purchase (`allTransactions()` shows it), but a
/// process that has already queried StoreKit keeps serving the entitlement cache it warmed:
/// `Transaction.currentEntitlements` stays empty and eligibility stays true. The same test
/// passes when it is the only one in the process. `AppStore.sync()` hangs rather than
/// reconciling. Production defaults `isEligibleForIntroOffer` to false on every failure path,
/// so the untested direction is the one the code is already biased towards.
/// `.serialized` is load-bearing: every test here opens its own `SKTestSession` and
/// `resetToDefaultState()` clears the whole StoreKit environment, so running them in
/// parallel lets one test wipe another's purchase mid-flight.
@MainActor
@Suite("Intro Offer Eligibility", .serialized)
struct IntroOfferEligibilityTests {
    /// Resolved from the test's own source location — see StoreKitConfigurationTests.
    private static let configurationURL = URL(filePath: #filePath)
        .deletingLastPathComponent()  // Monetization
        .deletingLastPathComponent()  // Core
        .deletingLastPathComponent()  // VittoraTests
        .deletingLastPathComponent()  // repository root
        .appending(path: "Vittora.storekit")

    /// One session for the whole process. The StoreKit test environment is per process,
    /// not per `SKTestSession`, so a second session buys nothing and costs a second setup.
    private static var sharedSession: SKTestSession?

    /// Every test here only reads, so the session is built and reset once.
    private func freshSession() throws -> SKTestSession {
        if let existing = Self.sharedSession { return existing }
        let session = try SKTestSession(contentsOf: Self.configurationURL)
        session.resetToDefaultState()
        session.clearTransactions()
        // Nothing here can dismiss a system sheet.
        session.disableDialogs = true
        Self.sharedSession = session
        return session
    }

    @Test("The configuration loads and serves every product the paywall asks for")
    func productsLoadFromTheConfiguration() async throws {
        _ = try freshSession()
        let products = try await Product.products(for: ProProduct.allIdentifiers)
        #expect(Set(products.map(\.id)) == Set(ProProduct.allIdentifiers))
    }

    @Test("A fresh account is eligible for the annual trial")
    func freshAccountIsEligible() async throws {
        _ = try freshSession()
        let products = try await Product.products(for: ProProduct.allIdentifiers)
        let annual = try #require(products.first { $0.id == ProProduct.annual.rawValue })
        let subscription = try #require(annual.subscription)

        #expect(subscription.introductoryOffer != nil)
        #expect(await subscription.isEligibleForIntroOffer)
    }

    /// Monthly carries no introductory offer, so it must never advertise one even while the
    /// group as a whole is eligible — group-level eligibility is what StoreKit answers.
    @Test("Monthly advertises no trial even when the group is eligible")
    func monthlyNeverAdvertisesATrial() async throws {
        _ = try freshSession()
        let products = try await Product.products(for: ProProduct.allIdentifiers)
        let monthly = try #require(products.first { $0.id == ProProduct.monthly.rawValue })
        let subscription = try #require(monthly.subscription)

        #expect(subscription.introductoryOffer == nil)
        // Eligibility is per group, so this is true for monthly too. The paywall's own
        // `offersTrial` gate is the `introductoryOffer != nil` check above, not this.
        #expect(await subscription.isEligibleForIntroOffer)
    }

    /// The app's own resolution path, not just raw StoreKit: this is the value
    /// `PaywallView.offersTrial` reads to decide between "Try It Free" and "Subscribe".
    @Test("PurchaseService resolves an eligible account as eligible")
    func purchaseServiceResolvesEligible() async throws {
        _ = try freshSession()
        let service = PurchaseService()
        await service.loadProducts()

        #expect(service.didFailToLoadProducts == false)
        #expect(service.isEligibleForIntroOffer)
    }
}

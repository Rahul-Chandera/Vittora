import Foundation
import Testing
@testable import Vittora

/// Guards `Vittora.storekit` at the repository root against the settled parts of DEC-011.
/// A product identifier that drifts between Swift and the StoreKit configuration produces a
/// paywall with no products in it — the cheapest possible bug to catch and the most expensive
/// one to ship, so it is checked here rather than discovered in review.
@Suite("StoreKit Configuration Tests")
struct StoreKitConfigurationTests {
    private struct Configuration: Decodable {
        let products: [Product]
        let subscriptionGroups: [SubscriptionGroup]
    }

    private struct Product: Decodable {
        let productID: String
        let type: String
        let familyShareable: Bool
        let displayPrice: String
    }

    private struct SubscriptionGroup: Decodable {
        let subscriptions: [Subscription]
    }

    private struct Subscription: Decodable {
        let productID: String
        let displayPrice: String
        let familyShareable: Bool
        let recurringSubscriptionPeriod: String
        let introductoryOffer: IntroductoryOffer?
    }

    private struct IntroductoryOffer: Decodable {
        let paymentMode: String
        let subscriptionPeriod: String
    }

    /// Resolved from the test's own source location so the check needs no bundle plumbing.
    private static let configurationURL = URL(filePath: #filePath)
        .deletingLastPathComponent()  // Monetization
        .deletingLastPathComponent()  // Core
        .deletingLastPathComponent()  // VittoraTests
        .deletingLastPathComponent()  // repository root
        .appending(path: "Vittora.storekit")

    private func loadConfiguration() throws -> Configuration {
        let data = try Data(contentsOf: Self.configurationURL)
        return try JSONDecoder().decode(Configuration.self, from: data)
    }

    @Test("Configuration declares exactly the products ProProduct knows about")
    func productIdentifiersMatchProProduct() throws {
        let configuration = try loadConfiguration()
        let declared = Set(
            configuration.products.map(\.productID)
                + configuration.subscriptionGroups.flatMap { $0.subscriptions.map(\.productID) }
        )
        #expect(declared == Set(ProProduct.allIdentifiers))
    }

    @Test("Lifetime is a Family Shareable non-consumable at $99.99")
    func lifetimeProduct() throws {
        let configuration = try loadConfiguration()
        let lifetime = configuration.products.first { $0.productID == ProProduct.lifetime.rawValue }
        try #require(lifetime != nil)
        #expect(lifetime?.type == "NonConsumable")
        #expect(lifetime?.familyShareable == true)
        #expect(lifetime?.displayPrice == "99.99")
    }

    @Test("Annual carries the 7-day free trial and is Family Shareable")
    func annualIntroductoryOffer() throws {
        let configuration = try loadConfiguration()
        let annual = configuration.subscriptionGroups
            .flatMap(\.subscriptions)
            .first { $0.productID == ProProduct.annual.rawValue }
        try #require(annual != nil)
        #expect(annual?.recurringSubscriptionPeriod == "P1Y")
        #expect(annual?.displayPrice == "39.99")
        #expect(annual?.familyShareable == true)
        // DEC-011: 7-day free trial, annual only.
        #expect(annual?.introductoryOffer?.paymentMode == "free")
        #expect(annual?.introductoryOffer?.subscriptionPeriod == "P1W")
    }

    @Test("Monthly has no trial and no Family Sharing")
    func monthlyHasNoIntroductoryOffer() throws {
        let configuration = try loadConfiguration()
        let monthly = configuration.subscriptionGroups
            .flatMap(\.subscriptions)
            .first { $0.productID == ProProduct.monthly.rawValue }
        try #require(monthly != nil)
        #expect(monthly?.recurringSubscriptionPeriod == "P1M")
        #expect(monthly?.displayPrice == "4.99")
        // DEC-011: no monthly trial, Family Sharing on annual and lifetime only.
        #expect(monthly?.introductoryOffer == nil)
        #expect(monthly?.familyShareable == false)
    }

    @Test("All subscriptions live in one group, so plans are mutually exclusive")
    func singleSubscriptionGroup() throws {
        let configuration = try loadConfiguration()
        #expect(configuration.subscriptionGroups.count == 1)
    }
}

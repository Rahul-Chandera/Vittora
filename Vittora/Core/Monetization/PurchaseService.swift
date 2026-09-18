import Foundation
import StoreKit

nonisolated enum PurchaseOutcome: Sendable, Equatable {
    case purchased
    case pending
    case cancelled
}

nonisolated enum PurchaseError: LocalizedError, Equatable {
    case unverified

    var errorDescription: String? {
        String(localized: "This purchase could not be verified. Nothing was unlocked. Contact Apple Support if you were charged.")
    }
}

@MainActor
@Observable
final class PurchaseService {
    private let entitlements: EntitlementStore
    private var updatesTask: Task<Void, Never>?
    private(set) var products: [Product] = []
    private(set) var level: EntitlementLevel
    private(set) var didFailToLoadProducts = false

    /// Whether the paywall may advertise the 7-day free trial to THIS Apple Account.
    ///
    /// Defaults to false and returns to false on every failure path, deliberately. The two
    /// mistakes are not symmetric: not showing a trial to an eligible user costs a
    /// conversion, while showing one to an ineligible user is a Guideline 3.1.2 violation
    /// — an advertised price the account cannot actually get. App Review commonly tests
    /// with an account that has already subscribed, so that is the likely path, not the
    /// rare one.
    private(set) var isEligibleForIntroOffer = false

    init(entitlements: EntitlementStore = EntitlementStore()) {
        self.entitlements = entitlements
        self.level = entitlements.cachedLevel()
    }

    /// Must be called at app launch so renewals, refunds, revocations and Ask-to-Buy approvals arriving out of band are applied.
    func start() {
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                await self?.handle(update)
            }
        }
        Task { await self.refreshEntitlement() }
        // Warm StoreKit's product cache at launch. SubscriptionStoreView runs its own
        // fetch when the paywall opens, and on a cold cache that is a network round trip
        // the user watches as "Loading Subscription" — measured at 10+ seconds on macOS.
        // Priming here means the store view resolves from cache instead. Failure is
        // ignored on purpose: this is a cache warm, and the paywall's own .task still
        // loads products and still sets didFailToLoadProducts for the degraded state.
        Task { await self.loadProducts() }
    }

    func stop() {
        updatesTask?.cancel()
        updatesTask = nil
    }

    /// Product.products(for:) returns [] rather than throwing when a storefront cannot serve
    /// the identifiers (unapproved products, unfinished ASC propagation, unsupported region).
    /// An empty success is indistinguishable from a failure from the user's point of view, so
    /// PaywallView keys its degraded state off didFailToLoadProducts tracking that outcome.
    func loadProducts() async {
        do {
            let loaded = try await Product.products(for: ProProduct.allIdentifiers)
            products = loaded.sorted { lhs, rhs in
                let lhsIndex = ProProduct.allIdentifiers.firstIndex(of: lhs.id) ?? .max
                let rhsIndex = ProProduct.allIdentifiers.firstIndex(of: rhs.id) ?? .max
                return lhsIndex < rhsIndex
            }
            didFailToLoadProducts = products.isEmpty
            isEligibleForIntroOffer = await Self.resolveIntroOfferEligibility(in: products)
        } catch {
            products = []
            didFailToLoadProducts = true
            isEligibleForIntroOffer = false
        }
    }

    /// Eligibility belongs to the subscription GROUP, not to one product, so annual and
    /// monthly always answer alike — StoreKit's own `isEligibleForIntroOffer` just forwards
    /// to `isEligibleForIntroOffer(for: subscriptionGroupID)`. Ask the annual plan, which is
    /// the one carrying the trial.
    ///
    /// The `introductoryOffer != nil` guard is the half that is easy to forget: an account
    /// can be eligible for an offer that the product does not have, and answering true there
    /// would advertise a trial that does not exist.
    private static func resolveIntroOfferEligibility(in products: [Product]) async -> Bool {
        guard let subscription = products
            .first(where: { $0.id == ProProduct.annual.rawValue })?
            .subscription,
            subscription.introductoryOffer != nil
        else { return false }
        return await subscription.isEligibleForIntroOffer
    }

    func product(for proProduct: ProProduct) -> Product? {
        products.first { $0.id == proProduct.rawValue }
    }

    /// NOTE for whoever configures an offer in App Store Connect: SubscriptionStoreView used
    /// to apply offer codes, promotional offers and win-back offers on its own, and owning
    /// the paywall means nothing does now. None are configured today, so nothing is broken —
    /// but a new one will silently do nothing until it is passed here as a PurchaseOption.
    @discardableResult
    func purchase(_ product: Product) async throws -> PurchaseOutcome {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            guard case .verified(let transaction) = verification else {
                // Signature check failed: grant nothing. Finish it anyway so StoreKit stops
                // redelivering a transaction we will never honour. AppStore.sync() via
                // restore() is the recovery path if a legitimate purchase ever lands here.
                if case .unverified(let transaction, _) = verification { await transaction.finish() }
                throw PurchaseError.unverified
            }
            await transaction.finish()
            await refreshEntitlement()
            return .purchased
        case .pending:
            // Ask to Buy or SCA. Nothing is unlocked now; Transaction.updates delivers the
            // approval later and refreshes the entitlement then.
            return .pending
        case .userCancelled:
            return .cancelled
        @unknown default:
            return .cancelled
        }
    }

    func restore() async throws {
        try await AppStore.sync()
        await refreshEntitlement()
    }

    private func handle(_ update: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = update else {
            if case .unverified(let transaction, _) = update { await transaction.finish() }
            return
        }
        await transaction.finish()
        await refreshEntitlement()
    }

    func refreshEntitlement() async {
        level = await entitlements.refresh()
    }

    /// Family Sharing is checked before the product, deliberately: annual and lifetime are
    /// both Family Shareable (DEC-013), so an inherited lifetime is still someone else's
    /// purchase and must not be described as this user's own.
    var proEntitlementKind: ProEntitlementKind {
        guard level == .pro, let snapshot = entitlements.cachedSnapshot() else { return .none }
        if snapshot.isFamilyShared == true { return .familyShared }
        if snapshot.productID == ProProduct.lifetime.rawValue { return .lifetime }
        return .subscription
    }
}

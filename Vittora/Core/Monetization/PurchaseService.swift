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
        } catch {
            products = []
            didFailToLoadProducts = true
        }
    }

    func product(for proProduct: ProProduct) -> Product? {
        products.first { $0.id == proProduct.rawValue }
    }

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

    /// SubscriptionStoreView runs its own purchase, so the transaction never reaches
    /// purchase(_:), and StoreKit does not redeliver an app-initiated purchase through
    /// Transaction.updates. The paywall hands the result here so verification, finishing
    /// and the entitlement refresh stay in exactly one place.
    @discardableResult
    func completeStorePurchase(_ result: Result<Product.PurchaseResult, any Error>) async -> Bool {
        guard case .success(let purchaseResult) = result,
              case .success(let verification) = purchaseResult else { return false }
        await handle(verification)
        return level == .pro
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
}

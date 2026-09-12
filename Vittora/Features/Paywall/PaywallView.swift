import SwiftUI
import StoreKit
import VittoraCore

struct PaywallView: View {
    var milestone: ConversionMilestone?
    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @State private var isPurchasingLifetime = false
    @State private var errorMessage: String?

    private let proFeatures: [String] = [
        String(localized: "Full tax planning and regime comparison"),
        String(localized: "Custom reports with PDF export"),
        String(localized: "Cash flow forecast and subscription audit"),
        String(localized: "50/30/20 report and emergency fund tracker"),
        String(localized: "Unlimited receipt scanning"),
        String(localized: "Every future Pro feature, included"),
    ]

    var body: some View {
        NavigationStack {
            SubscriptionStoreView(
                productIDs: [ProProduct.annual.rawValue, ProProduct.monthly.rawValue]
            ) {
                marketingContent
            }
            .subscriptionStoreControlStyle(.prominentPicker)
            .storeButton(.visible, for: .restorePurchases)
            .storeButton(.visible, for: .policies)
            .subscriptionStorePolicyDestination(for: .termsOfService) {
                LegalDocumentView(document: .termsOfService)
            }
            .subscriptionStorePolicyDestination(for: .privacyPolicy) {
                LegalDocumentView(document: .privacyPolicy)
            }
            // AA-safe brand green. VColors.primary (#3FCFA4) behind the white Subscribe label is
            // 1.97:1; primaryOnSurface (#1F7D61) is the same hue dark enough to clear 4.5:1, so the
            // paywall needs no DEC-012 contrast exemption.
            .tint(VColors.primaryOnSurface)
            .onInAppPurchaseCompletion { _, result in
                // Entitlement itself comes from the Transaction.updates listener in PurchaseService;
                // this only closes the sheet once StoreKit says the purchase went through.
                if case .success(.success(_)) = result { dismiss() }
            }
            .background(VColors.groupedBackground)
            .navigationTitle(String(localized: "Vittora Pro"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Close")) { dismiss() }
                        .accessibilityIdentifier("paywall-close-button")
                }
            }
            .task { await dependencies.purchaseService.loadProducts() }
            .alert(
                String(localized: "Purchase Failed"),
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button(String(localized: "OK"), role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    @ViewBuilder
    private var marketingContent: some View {
        VStack(alignment: .leading, spacing: VSpacing.lg) {
            Image(systemName: "sparkles")
                .font(.largeTitle)
                .foregroundStyle(VColors.primaryOnSurface)
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)

            Text(headline)
                .font(.title2.bold())
                .foregroundStyle(VColors.textPrimary)

            Text(String(localized: "Vittora Pro unlocks the forward-looking analysis. Your records, your splits, iCloud sync and CSV export stay free, always."))
                .font(.subheadline)
                .foregroundStyle(VColors.textSecondary)

            ForEach(proFeatures, id: \.self) { feature in
                HStack(alignment: .firstTextBaseline, spacing: VSpacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(VColors.primaryOnSurface)
                        .accessibilityHidden(true)
                    Text(feature)
                        .foregroundStyle(VColors.textPrimary)
                }
            }

            if let product = dependencies.purchaseService.product(for: .lifetime) {
                HStack(spacing: VSpacing.sm) {
                    Button {
                        Task {
                            isPurchasingLifetime = true
                            defer { isPurchasingLifetime = false }
                            do {
                                if try await dependencies.purchaseService.purchase(product) == .purchased {
                                    dismiss()
                                }
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                        }
                    } label: {
                        Text(String(localized: "Or buy Vittora Pro Lifetime for \(product.displayPrice), once"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(VColors.primaryOnSurface)
                    }
                    .accessibilityIdentifier("paywall-lifetime-button")
                    .disabled(isPurchasingLifetime)

                    if isPurchasingLifetime {
                        ProgressView()
                    }
                }
            }

            Text(disclosure)
                .font(.footnote)
                .foregroundStyle(VColors.textSecondary)
                .accessibilityIdentifier("paywall-auto-renew-disclosure")
        }
        .padding(.horizontal, VSpacing.screenPadding)
        .padding(.top, VSpacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var headline: String {
        switch milestone {
        case .tenthTransaction:
            String(localized: "You're keeping real records now")
        case .firstOCRScan:
            String(localized: "Scan every receipt, not just five")
        case .firstReport:
            String(localized: "See where your money is going next")
        case .firstSplit:
            String(localized: "There's more in Vittora Pro")
        case .ocrMonthlyLimitReached:
            String(localized: "You've used this month's free receipt scans")
        case nil:
            String(localized: "Everything in Vittora Pro")
        }
    }

    private var disclosure: String {
        if let annual = dependencies.purchaseService.product(for: .annual)?.displayPrice,
           let monthly = dependencies.purchaseService.product(for: .monthly)?.displayPrice {
            return String(localized: "Annual includes a 7-day free trial; your Apple Account is charged \(annual) when it ends. Monthly is \(monthly). Both renew automatically unless you turn off auto-renew at least 24 hours before the period ends, and renewals are charged within 24 hours of the period ending. Manage or cancel in your Apple Account settings. Subscribing before a trial ends forfeits the unused part of the trial. Vittora Pro Lifetime is a one-time purchase and does not renew.")
        }
        return String(localized: "Annual includes a 7-day free trial, then renews yearly. Monthly renews every month. Both renew automatically unless you turn off auto-renew at least 24 hours before the period ends, and renewals are charged within 24 hours of the period ending. Manage or cancel in your Apple Account settings. Subscribing before a trial ends forfeits the unused part of the trial. Vittora Pro Lifetime is a one-time purchase and does not renew.")
    }
}

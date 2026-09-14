import SwiftUI
import StoreKit
import VittoraCore

struct PaywallView: View {
    var milestone: ConversionMilestone?
    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @State private var isPurchasingLifetime = false
    @State private var errorMessage: String?
    @State private var isRetrying = false
    @State private var isRestoring = false
    @State private var restoreMessage: String?
    @State private var isCompletingPurchase = false

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
            Group {
                if dependencies.purchaseService.level == .pro {
                    alreadySubscribedContent
                } else if dependencies.purchaseService.didFailToLoadProducts {
                    productsUnavailableContent
                } else {
                    subscriptionStore
                }
            }
            .background(VColors.groupedBackground)
            .overlay {
                if isCompletingPurchase {
                    ZStack {
                        VColors.groupedBackground.opacity(0.8).ignoresSafeArea()
                        ProgressView(String(localized: "Completing your purchase…"))
                            .accessibilityIdentifier("paywall-completing-progress")
                    }
                    .transition(.opacity)
                }
            }
            .navigationTitle(String(localized: "Vittora Pro"))
            .toolbar { closeToolbarItem }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
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
            .alert(
                String(localized: "Restore Purchases"),
                isPresented: Binding(
                    get: { restoreMessage != nil },
                    set: { if !$0 { restoreMessage = nil } }
                )
            ) {
                Button(String(localized: "OK"), role: .cancel) { restoreMessage = nil }
            } message: {
                Text(restoreMessage ?? "")
            }
        }
    }

    /// The one dismiss control for this sheet, in the navigation bar so it aligns with the
    /// inline title. SubscriptionStoreView's built-in control is hidden (see subscriptionStore),
    /// so attaching this to every branch still leaves exactly one way out.
    @ToolbarContentBuilder
    private var closeToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(String(localized: "Close")) { dismiss() }
                .accessibilityIdentifier("paywall-close-button")
        }
    }

    private var subscriptionStore: some View {
        SubscriptionStoreView(
            productIDs: [ProProduct.annual.rawValue, ProProduct.monthly.rawValue]
        ) {
            marketingContent
        }
        .subscriptionStoreControlStyle(.prominentPicker)
        // The default soft scroll edge effect fades the marketing content and StoreKit's own
        // auto-renew description into a half-legible ghost behind the purchase buttons — an
        // App Store Review 3.1.2 legibility problem and two accessibility-audit contrast
        // failures. `.hard` cuts the content off at a solid edge instead of fading it. No
        // bottom padding is added because SubscriptionStoreView already insets its scroll
        // content past the control area: scrolling to the bottom shows the full disclosure
        // paragraph, the policy links and the plan picker clear of the buttons.
        .scrollEdgeEffectStyle(.hard, for: .bottom)
        // SubscriptionStoreView's own dismiss control renders inside its scroll content, so it
        // can never line up with the navigation title. Hide it and let the navigation bar own
        // the single Close control for every branch of this sheet.
        .storeButton(.hidden, for: .cancellation)
        .storeButton(.visible, for: .restorePurchases)
        .storeButton(.visible, for: .policies)
        .subscriptionStorePolicyDestination(for: .termsOfService) {
            LegalDocumentView(document: .termsOfService)
        }
        .subscriptionStorePolicyDestination(for: .privacyPolicy) {
            LegalDocumentView(document: .privacyPolicy)
        }
        // The tint paints every filled control this view draws: StoreKit's purchase CTA and
        // the lifetime Button below. Brand green #3FCFA4 is the app-wide prominent-button
        // colour — every .borderedProminent button in the app uses VColors.primary; this
        // view and ProLockView were the only two outliers. White on #3FCFA4 is 1.97:1 —
        // the pairing DEC-012 accepts for CTAs by owner decision. VERIFIED on the iPhone 16
        // simulator: StoreKit derives a BLACK label on this fill, measured at 10.56:1. It
        // exposes no API to override the purchase-button label colour, so that is accepted
        // and left alone rather than reimplementing Apple's control. DEC-023 supersedes
        // DEC-018.
        .tint(VColors.primary)
        // `.tint` would otherwise repaint the Terms of Service and Privacy Policy links in
        // #3FCFA4 — pale green foreground text on a near-white page, which DEC-012 does NOT
        // cover (it covers white-on-green FILLS) and which is a real legibility regression.
        // Keep the links at the AA-safe #17604A.
        .subscriptionStorePolicyForegroundStyle(VColors.primaryOnSurface)
        .onInAppPurchaseCompletion { _, result in
            isCompletingPurchase = true
            defer { isCompletingPurchase = false }
            if await dependencies.purchaseService.completeStorePurchase(result) { dismiss() }
        }
    }

    @ViewBuilder
    private var alreadySubscribedContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VSpacing.lg) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.largeTitle)
                    .foregroundStyle(VColors.primaryOnSurface)
                    .frame(maxWidth: .infinity)
                    .accessibilityHidden(true)

                Text(String(localized: "You already have Vittora Pro"))
                    .font(.title3.bold())
                    .foregroundStyle(VColors.textPrimary)
                    .accessibilityIdentifier("paywall-already-subscribed")

                Text(String(localized: "Every Pro feature is unlocked on this device. You can change or cancel your plan any time in your Apple Account settings."))
                    .font(.subheadline)
                    .foregroundStyle(VColors.textSecondary)
            }
            .padding(.horizontal, VSpacing.screenPadding)
            .padding(.top, VSpacing.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var productsUnavailableContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VSpacing.lg) {
                VStack(alignment: .leading, spacing: VSpacing.lg) {
                    Image(systemName: "exclamationmark.icloud")
                        .font(.largeTitle)
                        .foregroundStyle(VColors.primaryOnSurface)
                        .frame(maxWidth: .infinity)
                        .accessibilityHidden(true)

                    Text(String(localized: "Vittora Pro pricing is unavailable right now"))
                        .font(.title3.bold())
                        .foregroundStyle(VColors.textPrimary)

                    Text(String(localized: "We could not reach the App Store, so prices and purchase options cannot be shown. Check your connection and try again. If you have already bought Vittora Pro, Restore Purchases brings it back on this device."))
                        .font(.subheadline)
                        .foregroundStyle(VColors.textSecondary)
                        .accessibilityIdentifier("paywall-products-unavailable")
                }
                .padding(.horizontal, VSpacing.screenPadding)

                HStack(spacing: VSpacing.sm) {
                    Button {
                        Task {
                            isRetrying = true
                            defer { isRetrying = false }
                            await dependencies.purchaseService.loadProducts()
                        }
                    } label: {
                        Text(String(localized: "Try Again"))
                    }
                    .vPrimaryActionButton()
                    .accessibilityIdentifier("paywall-retry-button")
                    .disabled(isRetrying)

                    if isRetrying {
                        ProgressView()
                    }
                }
                .padding(.horizontal, VSpacing.screenPadding)

                HStack(spacing: VSpacing.sm) {
                    Button {
                        Task {
                            isRestoring = true
                            defer { isRestoring = false }
                            do {
                                try await dependencies.purchaseService.restore()
                                restoreMessage = dependencies.purchaseService.level == .pro
                                    ? String(localized: "Vittora Pro is restored on this device.")
                                    : String(localized: "No previous Vittora Pro purchase was found for this Apple Account.")
                            } catch {
                                restoreMessage = error.localizedDescription
                            }
                        }
                    } label: {
                        Text(String(localized: "Restore Purchases"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(VColors.primaryOnSurface)
                    }
                    .accessibilityIdentifier("paywall-restore-button")
                    .disabled(isRestoring)

                    if isRestoring {
                        ProgressView()
                    }
                }
                .padding(.horizontal, VSpacing.screenPadding)

                marketingContent
            }
        }
    }

    @ViewBuilder
    private var marketingContent: some View {
        VStack(alignment: .leading, spacing: VSpacing.lg) {
            Image(systemName: "sparkles")
                .font(.largeTitle)
                // Brand green by owner decision (DEC-024). Decorative and
                // accessibilityHidden, so no contrast rule applies to it.
                .foregroundStyle(VColors.primary)
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
                        // Monochrome: the foreground colour is the disc and the check is
                        // knocked out of it in the page colour, so the check renders at
                        // 1.97:1 on #3FCFA4. Brand green by owner decision (DEC-024), which
                        // supersedes DEC-023's reasoning for keeping these #17604A. These
                        // are accessibilityHidden decorative glyphs that repeat the adjacent
                        // label verbatim, so nothing is conveyed by the glyph alone and no
                        // DEC-012 exemption is needed — the audit never samples them.
                        .foregroundStyle(VColors.primary)
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
                            // iOS 26 draws this bare Button as a prominent capsule filled
                            // with the ambient tint, which is now #3FCFA4. White on
                            // #3FCFA4 is 1.97:1 — the DEC-012 pairing, accepted for CTAs
                            // by owner decision. Note the asymmetry, because it is real
                            // and deliberate: StoreKit derives a BLACK label for its own
                            // purchase button on this identical fill, so the two CTAs on
                            // this screen carry different label colours. We control this
                            // one and keep it white per DEC-012 and to match ProLockView;
                            // we cannot control StoreKit's. KNOWN GAP: testPaywallAccessibilityAudit
                            // does NOT currently flag this control, because in the state
                            // that test samples the button is off-screen or behind the
                            // navigation bar, where the audit's viewport rules excuse it.
                            // So it carries no DEC-012 exemption entry today. If the audit
                            // ever reaches it unoccluded it will fail on this pairing, and
                            // the fix is to add paywall-lifetime-button to the exemptions
                            // in AccessibilityAuditUITests deliberately, not to change the
                            // colour.
                            .foregroundStyle(Color.white)
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

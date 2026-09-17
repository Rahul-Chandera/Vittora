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

    #if os(macOS)
    /// Horizontal inset that lines the lifetime button up with StoreKit's purchase button.
    /// Measured against the 520pt dialog, where StoreKit insets its CTA to 360pt wide and
    /// our marketing column is 440pt after `screenPadding`.
    private let macLifetimeButtonInset: CGFloat = 40
    #endif

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
        #if os(macOS)
        // A sheet on macOS is a fixed-size dialog, not a full-height sheet: without an
        // explicit size AppKit sizes it to something this branch's content overflows, so
        // the marketing list scrolled inside a cramped box and "Restore Subscription" sat
        // hard against the Close bar.
        //
        // Scoped to THIS branch deliberately. Putting it on the NavigationStack sized every
        // branch, and alreadySubscribedContent is four lines of text — it rendered with
        // ~500pt of empty space below it. Only the store needs the height.
        .frame(minWidth: 520, idealWidth: 560, minHeight: 620, idealHeight: 660)
        // 720 made the dialog taller than a default 1200x800 window: AppKit clipped the
        // sheet's own Close bar against the window edge. 660 + title bar + Close bar fits.
        #endif
        .subscriptionStoreControlStyle(.prominentPicker)
        // PROPOSAL: .automatic renders as "Accept Offer" under the Xcode 27 SDK. This is
        // the only API that influences that label.
        .subscriptionStoreButtonLabel(.action)
        // The default soft scroll edge effect fades the marketing content and StoreKit's own
        // auto-renew description into a half-legible ghost behind the purchase buttons — an
        // App Store Review 3.1.2 legibility problem and two accessibility-audit contrast
        // failures. `.hard` cuts the content off at a solid edge instead of fading it. No
        // bottom padding is added because SubscriptionStoreView already insets its scroll
        // content past the control area: scrolling to the bottom shows the full disclosure
        // paragraph, the policy links and the plan picker clear of the buttons.
        .scrollEdgeEffectStyle(.hard, for: .bottom)
        // KNOWN, UNFIXED (macOS): `.scrollEdgeEffectStyle` is a no-op here, so StoreKit's
        // pinned purchase controls float over the plan cards with nothing behind them and
        // the Yearly card reads straight through the CTA. Three fixes were built and
        // captured against a 1200x800 window and none reached StoreKit's macOS control
        // area: .subscriptionStoreControlBackground with an opaque Color, the same with
        // .gradientMaterial, and .contentMargins(.bottom:for: .scrollContent) — all three
        // rendered pixel-identical to no modifier at all. Backing that footer needs the
        // picker and the controls moved out of SubscriptionStoreView, which is a paywall
        // restructure, not a modifier. Same root cause as the iPad note below.
        // KNOWN, UNFIXED (iPad only): the last feature row, the lifetime button and the
        // disclosure come to rest UNDER the price caption, purchase button and Restore,
        // faded by the scroll edge effect. The claim above that SubscriptionStoreView
        // insets its scroll content past its own controls holds on iPhone and does NOT
        // hold on iPad. Three fixes were tried against iPad Pro 11 and none reached
        // StoreKit's internal scroll view: bottom padding on marketingContent (no effect —
        // it extends the scroll extent, not the resting position), .scrollEdgeEffectHidden
        // (removed the fade and exposed the overlap as plain text-on-text, worse), and
        // .contentMargins(.bottom:for: .scrollContent) (not honoured). The content is
        // still reachable by scrolling. Fixing this needs the lifetime button and
        // disclosure moved OUT of the store view's marketing content, which is a paywall
        // restructure, not a modifier.
        // SubscriptionStoreView's own dismiss control renders inside its scroll content, so it
        // can never line up with the navigation title. Hide it and let the navigation bar own
        // the single Close control for every branch of this sheet.
        .storeButton(.hidden, for: .cancellation)
        .storeButton(.visible, for: .restorePurchases)
        // StoreKit draws its policy links as 14pt text: the accessibility audit measured
        // them at 95.3x14.3 and 78.7x14.3 and failed them as hit regions, and there is no
        // API to size them. They were always that small — reducing the top padding above
        // the hero simply lifted them into the audited viewport for the first time. So
        // draw our own instead, in the same place and with the same wording, at the 44pt
        // minimum. `.subscriptionStorePolicyDestination` and
        // `.subscriptionStorePolicyForegroundStyle` went with them: both only drive
        // StoreKit's own buttons and are dead once those are hidden.
        .storeButton(.hidden, for: .policies)
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
                    // Brand green with the rest of the paywall's decorative marks
                    // (DEC-024). This was missed when the hero and the feature discs
                    // moved, leaving it the only dark-green mark on any paywall surface.
                    // accessibilityHidden and purely decorative, so no contrast rule
                    // applies and no DEC-012 exemption is needed.
                    .foregroundStyle(VColors.primary)
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
            // Without this the description sits hard against the dialog's Close bar on
            // macOS, where the sheet is a fixed-size box rather than a scrolling sheet.
            .padding(.bottom, VSpacing.xl)
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

            Text(String(localized: "Your records, splits, iCloud sync and CSV export stay free, always."))
                .font(.subheadline)
                .foregroundStyle(VColors.textSecondary)

            ForEach(highlightedFeatures, id: \.self) { feature in
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
                // One step down from body. Set on the row, not the label, so the checkmark
                // glyph scales with the text instead of sitting oversized beside it.
                // Dynamic Type still drives the absolute size — this is relative.
                .font(.subheadline)
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
                        Text(String(localized: "Vittora Pro Lifetime · \(product.displayPrice) once"))
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
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
                            .foregroundStyle(VColors.primaryOnSurface)
                            .padding(.vertical, VSpacing.md)
                            // One capsule, drawn once. `.bordered` + `.buttonBorderShape`
                            // draws its OWN edge, so stacking an overlay stroke on top of
                            // it rendered as a double border — obvious on macOS, where the
                            // bordered style's edge is opaque. Painting the fill and the
                            // stroke here, under `.buttonStyle(.plain)`, gives one edge on
                            // every platform.
                            .background(VColors.primary.opacity(0.12), in: .capsule)
                            .overlay {
                                Capsule().strokeBorder(VColors.primaryOnSurface, lineWidth: 1.5)
                            }
                    }
                    // PROPOSAL: secondary, not a second primary. It was the same brand
                    // green, size and weight as StoreKit's purchase button, so the screen
                    // had two competing primary actions and no signal which was the main
                    // path. The outlined capsule reads as the alternative it is.
                    //
                    // `.plain` is load-bearing: a bare Button inside SubscriptionStoreView
                    // is drawn by iOS as a prominent filled capsule, which is exactly the
                    // second primary this avoids.
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("paywall-lifetime-button")
                    .disabled(isPurchasingLifetime)

                    if isPurchasingLifetime {
                        ProgressView()
                    }
                }
                #if os(macOS)
                // StoreKit insets its own purchase button well inside the dialog, while our
                // marketing column runs the full content width — so this button rendered
                // noticeably wider than the CTA directly below it. Match the CTA instead of
                // the text column. iOS is left alone: there the two already line up.
                .padding(.horizontal, macLifetimeButtonInset)
                #endif
            }

            Text(disclosure)
                .font(.footnote)
                .foregroundStyle(VColors.textSecondary)
                .accessibilityIdentifier("paywall-auto-renew-disclosure")

            policyLinks
        }
        .padding(.horizontal, VSpacing.screenPadding)
        .padding(.top, VSpacing.xxs)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Replaces StoreKit's own policy links, which it draws at 14pt and the audit fails
    /// as hit regions. Same wording and the same position in the column; `minHeight: 44`
    /// is what the audit measures, and `.plain` keeps a bare Button inside
    /// SubscriptionStoreView from being drawn by iOS as a prominent filled capsule.
    ///
    /// Kept at #17604A rather than the ambient tint: `.tint` would paint these #3FCFA4,
    /// pale green text on a near-white page, which DEC-012 does NOT cover — it covers
    /// white-on-green FILLS — and which is a real legibility regression.
    private var policyLinks: some View {
        HStack(spacing: VSpacing.xs) {
            policyLink(.termsOfService)
            Text(String(localized: "and"))
                .font(.footnote)
                .foregroundStyle(VColors.textSecondary)
            policyLink(.privacyPolicy)
        }
        .frame(maxWidth: .infinity)
    }

    private func policyLink(_ document: LegalDocument) -> some View {
        NavigationLink {
            LegalDocumentView(document: document)
        } label: {
            Text(document.title)
                .font(.footnote)
                .foregroundStyle(VColors.primaryOnSurface)
                .padding(.horizontal, VSpacing.xxs)
                .frame(minHeight: 44)
                // `.frame` alone grew the tap target but NOT the accessibility element:
                // the audit still measured the text's own bounds at 15.7pt. `.accessibility`
                // is what makes the reported frame match the 44pt one.
                .contentShape([.interaction, .accessibility], Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("paywall-policy-\(document.rawValue)")
    }

    /// PROPOSAL: four, not six.
    ///
    /// Every row here pushes StoreKit's plan cards further down, and they were already
    /// below the fold. The two dropped rows are the least concrete: the 50/30/20 and
    /// emergency-fund line duplicates "reports", and "every future Pro feature" is a
    /// promise rather than a feature. Both still appear on the website's pricing page.
    private var highlightedFeatures: [String] {
        Array(proFeatures.prefix(3)) + proFeatures.filter { $0.contains("receipt") }
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
        // Deliberately left at full length. Shortening this was proposed alongside the
        // rest of the trim and rejected by the owner: it is the guideline 3.1.2 surface,
        // and this exact wording is what passed review with 1.7.0. The paywall gets its
        // space back from the blurb, the feature list and the lifetime button instead.
        if let annual = dependencies.purchaseService.product(for: .annual)?.displayPrice,
           let monthly = dependencies.purchaseService.product(for: .monthly)?.displayPrice {
            return String(localized: "Annual includes a 7-day free trial; your Apple Account is charged \(annual) when it ends. Monthly is \(monthly). Both renew automatically unless you turn off auto-renew at least 24 hours before the period ends, and renewals are charged within 24 hours of the period ending. Manage or cancel in your Apple Account settings. Subscribing before a trial ends forfeits the unused part of the trial. Vittora Pro Lifetime is a one-time purchase and does not renew.")
        }
        return String(localized: "Annual includes a 7-day free trial, then renews yearly. Monthly renews every month. Both renew automatically unless you turn off auto-renew at least 24 hours before the period ends, and renewals are charged within 24 hours of the period ending. Manage or cancel in your Apple Account settings. Subscribing before a trial ends forfeits the unused part of the trial. Vittora Pro Lifetime is a one-time purchase and does not renew.")
    }
}

import SwiftUI
import StoreKit
#if os(iOS)
import UIKit
#endif
import VittoraCore

/// An iPad sheet is a fixed-size form sheet — 620pt tall — no matter how much screen there
/// is, and this screen needs about 780pt. In landscape that left the third plan card not
/// merely below the fold but off screen entirely, along with the disclosure and any hint
/// that the content continued.
///
/// So: the form sheet, kept at its form width and shape, with a taller height. `.page` was
/// tried first and is the wrong instrument — it sizes against the screen and turns the
/// dialog into something close to full screen, which is not what this needed.
/// `.form.fitted(vertical: true)` is wrong too: it measured the safeAreaInset footer as the
/// whole content and collapsed the sheet to a title, a caption and the CTA. Both were built
/// and captured, so neither needs trying again.
///
/// UIKit clamps a proposal taller than the screen, so no explicit cap is needed here —
/// which is just as well, because PresentationSizingContext exposes no container size.
private struct TallerFormSizing: PresentationSizing {
    /// Enough for the hero, the four bullets, the policy links, three plan cards and the
    /// disclosure, measured against the rendered screen rather than guessed.
    private let height: CGFloat = 800

    func proposedSize(
        for root: PresentationSizingRoot,
        context: PresentationSizingContext
    ) -> ProposedViewSize {
        let form = FormPresentationSizing.form.proposedSize(for: root, context: context)
        return ProposedViewSize(width: form.width, height: height)
    }
}

/// Idiom-scoped rather than applied everywhere: on iPhone the sheet is already full width
/// and this would be a silent no-op the next reader has to re-derive.
private struct PaywallSheetSizing: ViewModifier {
    func body(content: Content) -> some View {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad {
            content.presentationSizing(TallerFormSizing())
        } else {
            content
        }
        #else
        content
        #endif
    }
}

struct PaywallView: View {
    var milestone: ConversionMilestone?
    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @State private var isPurchasingPlan = false
    /// Annual is preselected: it carries the trial, and StoreKit's picker defaulted to it.
    @State private var selectedPlan: ProProduct = .annual
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
        String(localized: "Financial health score and spending outlook"),
        String(localized: "Unlimited receipt scanning"),
        String(localized: "Every future Pro feature, included"),
    ]

    var body: some View {
        NavigationStack {
            Group {
                if dependencies.purchaseService.level == .pro {
                    alreadySubscribedContent
                } else if !AppStore.canMakePayments {
                    // Before the network branch below, deliberately: this device cannot buy
                    // anything regardless of whether the App Store is reachable, so offering
                    // a Try Again button would be a dead end.
                    paymentsUnavailableContent
                } else if dependencies.purchaseService.didFailToLoadProducts {
                    productsUnavailableContent
                } else {
                    customStore
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
            .modifier(PaywallSheetSizing())
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
    /// inline title. Every branch of this sheet attaches it, so there is exactly one way out.
    @ToolbarContentBuilder
    private var closeToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(String(localized: "Close")) { dismiss() }
                .accessibilityIdentifier("paywall-close-button")
        }
    }

    /// Our own store, in place of SubscriptionStoreView (option C).
    ///
    /// The framework laid the screen out as [our content] -> [policy links] -> [picker] ->
    /// [pinned controls] and nothing could be placed after the picker, which is what forced
    /// the plan cards below the fold on every platform and left three defects with no
    /// supported fix: the pinned controls floating over the cards with no background on
    /// macOS, the same overlap on iPad, and a CTA reading "Accept Offer" because
    /// `.subscriptionStoreButtonLabel` does not reach that string. Owning the scroll view
    /// and the footer is what makes all three ordinary layout again.
    private var customStore: some View {
        ScrollView {
            // md, not lg. A third card needs roughly 55pt that the column does not have on a
            // phone sheet, and this plus the tighter card padding below is where it comes
            // from — rather than from dropping a bullet or moving the policy links, which
            // would change the agreed content order.
            VStack(alignment: .leading, spacing: VSpacing.md) {
                marketingContent
                planCard(.annual)
                planCard(.monthly)
                planCard(.lifetime)
                // The HIG asks for Family Sharing to be mentioned "in places where people
                // learn about the content you offer". Annual and Lifetime are Family
                // Shareable (DEC-013), Monthly is not, and until now the only place that
                // said so was the Terms document.
                Label(
                    String(localized: "Yearly and Lifetime can be shared with up to five family members through Family Sharing."),
                    systemImage: "person.2"
                )
                .font(.footnote)
                .foregroundStyle(VColors.textSecondary)
                .accessibilityIdentifier("paywall-family-sharing")

                Text(disclosure)
                    .font(.footnote)
                    .foregroundStyle(VColors.textSecondary)
                    .accessibilityIdentifier("paywall-auto-renew-disclosure")
            }
            .padding(.horizontal, VSpacing.screenPadding)
            .padding(.top, VSpacing.xxs)
            .padding(.bottom, VSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .safeAreaInset(edge: .bottom) { purchaseFooter }
        #if os(macOS)
        // A sheet on macOS is a fixed-size dialog, not a full-height sheet: without an
        // explicit size AppKit sizes it to something this branch's content overflows.
        // Scoped to THIS branch deliberately — alreadySubscribedContent is four lines of
        // text and rendered with ~500pt of empty space below it when this sat on the
        // NavigationStack. 660 + title bar + Close bar fits a default 1200x800 window;
        // 720 did not, and AppKit clipped the sheet's own Close bar against the edge.
        .frame(minWidth: 520, idealWidth: 560, minHeight: 620, idealHeight: 660)
        #endif
    }

    /// One selectable plan. Selection is the card's own job rather than a separate control,
    /// so the whole card is the hit target and the audit measures a card, not a radio dot.
    @ViewBuilder
    private func planCard(_ plan: ProProduct) -> some View {
        if let product = dependencies.purchaseService.product(for: plan) {
            let isSelected = selectedPlan == plan
            Button {
                selectedPlan = plan
            } label: {
                HStack(alignment: .top, spacing: VSpacing.md) {
                    VStack(alignment: .leading, spacing: VSpacing.xxs) {
                        Text(product.displayName)
                            .font(.headline)
                            .foregroundStyle(VColors.textPrimary)
                        Text(priceCaption(for: plan, product: product))
                            .font(.subheadline)
                            .foregroundStyle(VColors.textSecondary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isSelected ? VColors.primary : VColors.textSecondary)
                        // The checkmark repeats what isSelected already reports through the
                        // trait below, so it conveys nothing on its own.
                        .accessibilityHidden(true)
                }
                .padding(VSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(VColors.secondaryGroupedBackground, in: .rect(cornerRadius: VSpacing.cornerRadiusLG))
                .overlay {
                    RoundedRectangle(cornerRadius: VSpacing.cornerRadiusLG)
                        .strokeBorder(
                            // The app's established hairline for an unselected card edge
                            // (TaxDisclaimerView, TransactionDetailView). There is no separator
                            // token, and inventing one for a single screen is not the job here.
                            isSelected ? VColors.primary : VColors.textTertiary.opacity(0.35),
                            lineWidth: isSelected ? 2 : 1
                        )
                }
                .contentShape([.interaction, .accessibility], Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("paywall-plan-\(plan.rawValue)")
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        }
    }

    /// "7 days free, then $39.99/year" only when this account can actually have the trial.
    /// Both halves matter: eligibility is group-wide, but the offer itself is on annual
    /// only, so monthly must never claim one. See PurchaseService.isEligibleForIntroOffer
    /// for why false is the safe default.
    private func priceCaption(for plan: ProProduct, product: Product) -> String {
        let period = periodPrice(for: plan, product: product)
        guard offersTrial(plan, product: product) else { return period }
        return String(localized: "7 days free, then \(period)")
    }

    private func periodPrice(for plan: ProProduct, product: Product) -> String {
        switch plan {
        case .annual: String(localized: "\(product.displayPrice)/year")
        case .monthly: String(localized: "\(product.displayPrice)/month")
        // Not a period at all — "once" is the whole point, and a bare price next to two
        // per-period ones would read as a third recurring plan.
        case .lifetime: String(localized: "\(product.displayPrice) once")
        }
    }

    private func offersTrial(_ plan: ProProduct, product: Product) -> Bool {
        guard plan.isSubscription,
              dependencies.purchaseService.isEligibleForIntroOffer
        else { return false }
        return product.subscription?.introductoryOffer != nil
    }

    private var selectedProduct: Product? {
        dependencies.purchaseService.product(for: selectedPlan)
    }

    /// The label StoreKit would not let us set. `.subscriptionStoreButtonLabel(.action)`
    /// had no effect on "Accept Offer" — that string was the framework's own.
    private var purchaseButtonLabel: String {
        if let product = selectedProduct, offersTrial(selectedPlan, product: product) {
            return String(localized: "Try It Free")
        }
        // Lifetime is a non-consumable. "Subscribe" on a one-time purchase is not a wording
        // preference, it misdescribes the transaction.
        if selectedPlan == .lifetime {
            return String(localized: "Purchase")
        }
        return String(localized: "Subscribe")
    }

    private var purchaseFooter: some View {
        VStack(spacing: VSpacing.sm) {
            if let product = selectedProduct {
                Text(priceCaption(for: selectedPlan, product: product))
                    .font(.footnote)
                    .foregroundStyle(VColors.textSecondary)
                    .accessibilityIdentifier("paywall-selected-plan-caption")
            }

            HStack(spacing: VSpacing.sm) {
                Button {
                    purchaseSelectedPlan()
                } label: {
                    Text(purchaseButtonLabel)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, VSpacing.md)
                        // Black, not white. DEC-012 accepts white on #3FCFA4 at 1.97:1 for
                        // CTAs, but StoreKit drew THIS button and derived a black label,
                        // measured at 10.56:1, and that is what shipped and what the
                        // accessibility audit has always sampled. Keeping black preserves
                        // both the look and a passing audit; switching to white would fail
                        // contrast here and the only way to green would be a new exemption,
                        // which is not a thing we add to suit the code. Fixed rather than
                        // adaptive on purpose: the fill does not change between themes, so
                        // an adaptive label would turn white in dark mode and drop to 1.97:1.
                        .foregroundStyle(Color.black)
                        .background(VColors.primary, in: .capsule)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("paywall-subscribe-button")
                .disabled(isPurchasingPlan || selectedProduct == nil)

                if isPurchasingPlan {
                    ProgressView()
                }
            }

            Button {
                restorePurchases()
            } label: {
                Text(String(localized: "Restore Subscription"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(VColors.primaryOnSurface)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, VSpacing.sm)
                    .contentShape([.interaction, .accessibility], Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("paywall-restore-button")
            .disabled(isRestoring)
        }
        .padding(.horizontal, VSpacing.screenPadding)
        .padding(.vertical, VSpacing.md)
        // An opaque background, which is the whole point of owning this footer: StoreKit's
        // pinned controls had none on macOS and the plan card read straight through them.
        .background(VColors.groupedBackground)
    }

    private func purchaseSelectedPlan() {
        guard let product = selectedProduct else { return }
        Task {
            isPurchasingPlan = true
            isCompletingPurchase = true
            defer {
                isPurchasingPlan = false
                isCompletingPurchase = false
            }
            do {
                if try await dependencies.purchaseService.purchase(product) == .purchased {
                    dismiss()
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func restorePurchases() {
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

                Text(alreadySubscribedDetail)
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

    /// Shown when `AppStore.canMakePayments` is false — parental restrictions, a managed
    /// device, or a restricted Apple Account.
    ///
    /// The In-App Purchase HIG (revised 17 September 2026) is explicit: "Display your store
    /// only when people can make payments. If someone can't make payments — for example,
    /// because of parental restrictions — consider hiding your store or displaying UI that
    /// explains why the store isn't available."
    ///
    /// Restore stays available. Purchases can be restored on a device that cannot make new
    /// ones — a family member's shared entitlement is exactly that case.
    @ViewBuilder
    private var paymentsUnavailableContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VSpacing.lg) {
                VStack(alignment: .leading, spacing: VSpacing.lg) {
                    Image(systemName: "lock.circle")
                        .font(.largeTitle)
                        .foregroundStyle(VColors.primaryOnSurface)
                        .frame(maxWidth: .infinity)
                        .accessibilityHidden(true)

                    Text(String(localized: "Purchases are turned off on this device"))
                        .font(.title3.bold())
                        .foregroundStyle(VColors.textPrimary)

                    Text(String(localized: "This device cannot make purchases, usually because of Screen Time restrictions or a device management profile. Vittora stays fully usable without Pro. If Vittora Pro was already bought on this Apple Account, Restore Subscription brings it back."))
                        .font(.subheadline)
                        .foregroundStyle(VColors.textSecondary)
                        .accessibilityIdentifier("paywall-payments-unavailable")
                }
                .padding(.horizontal, VSpacing.screenPadding)

                HStack(spacing: VSpacing.sm) {
                    Button {
                        restorePurchases()
                    } label: {
                        Text(String(localized: "Restore Subscription"))
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
            }
            .padding(.top, VSpacing.xl)
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
                        restorePurchases()
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
        VStack(alignment: .leading, spacing: VSpacing.md) {
            Image(systemName: "sparkles")
                .font(.title)
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

    /// One of three, because the old single sentence was wrong for two of them: it told a
    /// family member to cancel a plan they do not own, and a Lifetime owner to manage a
    /// renewal that does not exist. Both sent the reader looking for a control that is not
    /// in their Apple Account settings.
    private var alreadySubscribedDetail: String {
        switch dependencies.purchaseService.proEntitlementKind {
        case .familyShared:
            String(localized: "Every Pro feature is unlocked on this device through Family Sharing. The family member who bought it manages the plan in their Apple Account settings.")
        case .lifetime:
            String(localized: "Every Pro feature is unlocked on this device. Vittora Pro Lifetime is a one-time purchase, so there is nothing to renew or cancel.")
        case .subscription, .none:
            String(localized: "Every Pro feature is unlocked on this device. You can change or cancel your plan any time in your Apple Account settings.")
        }
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

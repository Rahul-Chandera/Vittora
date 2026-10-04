#if os(iOS)
import ActivityKit
import SwiftUI
import VittoraCore
import WidgetKit

/// Lock Screen and Dynamic Island presentation for a shopping session
/// (M3.3.1, carrying M3.3.2's remaining-budget figure).
///
/// Everything rendered here comes from the activity's content state. Nothing is
/// recomputed in the extension: if the widget derived "over budget" itself it
/// could disagree with what the app just showed the user, and the two surfaces
/// sitting side by side with different answers is worse than either being wrong.
struct ShoppingSessionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ShoppingSessionAttributes.self) { context in
            lockScreenView(context)
                .activityBackgroundTint(Color.black.opacity(0.35))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text(title(context))
                    } icon: {
                        Image(systemName: "cart.fill")
                    }
                    .font(.caption)
                    .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(itemCountText(context))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(currency(context.state.runningTotal, context))
                            .font(.title2.weight(.semibold))
                            .monospacedDigit()
                        Spacer()
                        if let remaining = context.state.budgetRemaining {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(remainingLabel(context))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(currency(remaining, context))
                                    .font(.callout.weight(.medium))
                                    .monospacedDigit()
                                    .foregroundStyle(context.state.isOverBudget ? .red : .primary)
                            }
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: "cart.fill")
            } compactTrailing: {
                // The running total is the one number worth the compact slot.
                Text(currency(context.state.runningTotal, context))
                    .monospacedDigit()
                    .foregroundStyle(context.state.isOverBudget ? .red : .primary)
            } minimal: {
                Image(systemName: "cart.fill")
                    .foregroundStyle(context.state.isOverBudget ? .red : .primary)
            }
        }
    }

    @ViewBuilder
    private func lockScreenView(_ context: ActivityViewContext<ShoppingSessionAttributes>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label {
                    Text(title(context))
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                } icon: {
                    Image(systemName: "cart.fill")
                }
                Spacer()
                Text(itemCountText(context))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .firstTextBaseline) {
                Text(currency(context.state.runningTotal, context))
                    .font(.title.weight(.semibold))
                    .monospacedDigit()

                Spacer()

                if let remaining = context.state.budgetRemaining {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(remainingLabel(context))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(currency(remaining, context))
                            .font(.headline)
                            .monospacedDigit()
                            .foregroundStyle(context.state.isOverBudget ? .red : .primary)
                    }
                }
            }
        }
        .padding()
    }

    /// An empty session name is allowed, so fall back rather than render a blank.
    private func title(_ context: ActivityViewContext<ShoppingSessionAttributes>) -> String {
        context.attributes.sessionName.isEmpty
            ? String(localized: "Shopping")
            : context.attributes.sessionName
    }

    private func remainingLabel(_ context: ActivityViewContext<ShoppingSessionAttributes>) -> String {
        context.state.isOverBudget
            ? String(localized: "Over budget")
            : String(localized: "Left")
    }

    private func itemCountText(_ context: ActivityViewContext<ShoppingSessionAttributes>) -> String {
        String(localized: "\(context.state.itemCount) items")
    }

    private func currency(
        _ amount: Decimal,
        _ context: ActivityViewContext<ShoppingSessionAttributes>
    ) -> String {
        amount.formatted(.currency(code: context.attributes.currencyCode))
    }
}
#endif

#if os(iOS)
import ActivityKit
import SwiftUI
import VittoraCore
import WidgetKit

/// Lock Screen and Dynamic Island presentation for a bill countdown (M3.3.3).
///
/// The countdown is rendered with a relative date style from the due date held
/// in the activity's *attributes*, so the widget counts down on its own and the
/// app never has to push an update just for the clock to tick. The only state
/// that changes is whether the bill has been paid.
struct BillCountdownLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BillCountdownAttributes.self) { context in
            lockScreenView(context)
                .activityBackgroundTint(Color.black.opacity(0.35))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text(context.attributes.billName)
                            .lineLimit(1)
                    } icon: {
                        Image(systemName: context.state.isPaid ? "checkmark.circle.fill" : "calendar")
                    }
                    .font(.caption)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(amountText(context))
                        .font(.caption.weight(.medium))
                        .monospacedDigit()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if context.state.isPaid {
                        Text(String(localized: "Paid"))
                            .font(.headline)
                            .foregroundStyle(.green)
                    } else {
                        Text(context.attributes.dueDate, style: .relative)
                            .font(.title3.weight(.semibold))
                            .monospacedDigit()
                    }
                }
            } compactLeading: {
                Image(systemName: context.state.isPaid ? "checkmark.circle.fill" : "calendar")
                    .foregroundStyle(context.state.isPaid ? .green : .primary)
            } compactTrailing: {
                if !context.state.isPaid {
                    Text(context.attributes.dueDate, style: .relative)
                        .monospacedDigit()
                }
            } minimal: {
                Image(systemName: context.state.isPaid ? "checkmark.circle.fill" : "calendar")
                    .foregroundStyle(context.state.isPaid ? .green : .primary)
            }
        }
    }

    @ViewBuilder
    private func lockScreenView(_ context: ActivityViewContext<BillCountdownAttributes>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label {
                    Text(context.attributes.billName)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                } icon: {
                    Image(systemName: context.state.isPaid ? "checkmark.circle.fill" : "calendar")
                }
                Spacer()
                Text(amountText(context))
                    .font(.subheadline.weight(.medium))
                    .monospacedDigit()
            }

            if context.state.isPaid {
                Text(String(localized: "Paid"))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.green)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(String(localized: "Due"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(context.attributes.dueDate, style: .relative)
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                }
            }
        }
        .padding()
    }

    private func amountText(_ context: ActivityViewContext<BillCountdownAttributes>) -> String {
        context.attributes.amount.formatted(.currency(code: context.attributes.currencyCode))
    }
}
#endif

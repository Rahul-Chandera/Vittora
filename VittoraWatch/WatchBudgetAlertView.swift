import SwiftUI

struct WatchBudgetAlertView: View {
    let threshold: BudgetAlertThreshold

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: threshold == .oneHundred ? "exclamationmark.triangle.fill" : "chart.pie.fill")
                .font(.title2)
            Text(String(localized: "Budget is \(threshold.rawValue)% used"))
                .font(.headline)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "Budget alert: \(threshold.rawValue)% used"))
        .accessibilityIdentifier("watch-budget-alert-\(threshold.rawValue)")
    }
}

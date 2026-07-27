import SwiftUI
import VittoraCore

/// Portrait, story-shaped share card. Amounts appear only when `includeAmounts` is true.
struct YearInReviewShareCard: View {
    let summary: YearInReviewSummary
    let includeAmounts: Bool

    private var lines: [String] {
        YearInReviewShareCopy.lines(
            summary: summary,
            includeAmounts: includeAmounts,
            currencyCode: summary.currencyCode
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                Text(line)
                    .font(index == 0 ? VTypography.title2 : (isFooter(line) ? VTypography.caption1 : VTypography.body))
                    .fontWeight(index == 0 ? .bold : .regular)
                    .foregroundStyle(isFooter(line) ? VColors.textSecondary : VColors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: index == 0 || isFooter(line) ? .center : .leading)
            }
            Spacer(minLength: 0)
        }
        .padding(36)
        .frame(width: 390, height: 694, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [VColors.primary.opacity(0.18), VColors.background],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(lines.joined(separator: ". "))
    }

    private func isFooter(_ line: String) -> Bool {
        line == String(localized: "Made with Vittora")
    }
}

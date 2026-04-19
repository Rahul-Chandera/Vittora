import SwiftUI

/// Horizontal stacked bar showing income distributed across tax brackets.
struct TaxBracketBarView: View {
    let estimate: TaxEstimate

    private let bracketColors: [Color] = [
        .green, .yellow, .orange, .red, .purple, .indigo, .pink
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: VSpacing.sm) {
            Text(String(localized: "Bracket Distribution"))
                .font(VTypography.subheadline)
                .foregroundStyle(VColors.textSecondary)

            // Stacked bar
            GeometryReader { geo in
                HStack(spacing: 2) {
                    // Tax-free portion
                    if estimate.totalDeductions > 0 {
                        let pct = fracOf(estimate.totalDeductions)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: geo.size.width * pct)
                            .overlay(alignment: .center) {
                                if pct > 0.08 {
                                    Text(String(localized: "Deduct."))
                                        .font(.system(size: 9))
                                        .foregroundStyle(.secondary)
                                        .adaptiveLineLimit(1)
                                }
                            }
                    }

                    ForEach(Array(estimate.bracketResults.enumerated()), id: \.element.id) { idx, result in
                        let pct = fracOf(result.taxableAmount)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(bracketColors[idx % bracketColors.count])
                            .frame(width: geo.size.width * pct)
                            .overlay(alignment: .center) {
                                if pct > 0.08 {
                                    Text("\(result.ratePercent.formatted(.number.precision(.fractionLength(0))))%")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }
                    }
                }
            }
            .frame(height: 32)

            // Legend
            TaxFlowLayout(spacing: VSpacing.xs) {
                if estimate.totalDeductions > 0 {
                    legendItem(color: .gray.opacity(0.4), label: String(localized: "Deductions"))
                }
                ForEach(Array(estimate.bracketResults.enumerated()), id: \.element.id) { idx, result in
                    legendItem(
                        color: bracketColors[idx % bracketColors.count],
                        label: "\(result.ratePercent.formatted(.number.precision(.fractionLength(0))))%"
                    )
                }
            }
        }
    }

    private func fracOf(_ amount: Decimal) -> CGFloat {
        guard estimate.grossIncome > 0 else { return 0 }
        let ratio = (amount / estimate.grossIncome as NSDecimalNumber).doubleValue
        return CGFloat(max(0, min(1, ratio)))
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(VTypography.caption2)
                .foregroundStyle(VColors.textSecondary)
        }
    }
}

// MARK: - Simple Flow Layout

private struct TaxFlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0; y += rowHeight + spacing; rowHeight = 0
            }
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                x = bounds.minX; y += rowHeight + spacing; rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
    }
}

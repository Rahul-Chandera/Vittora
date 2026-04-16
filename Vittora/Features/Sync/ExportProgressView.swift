import SwiftUI

enum ExportProgressPhase: Sendable, Equatable {
    case preparing
    case generating
    case finalizing

    var progressValue: Double {
        switch self {
        case .preparing:
            0.2
        case .generating:
            0.65
        case .finalizing:
            0.95
        }
    }

    var title: String {
        switch self {
        case .preparing:
            String(localized: "Preparing export")
        case .generating:
            String(localized: "Generating file")
        case .finalizing:
            String(localized: "Finalizing share sheet")
        }
    }

    var detail: String {
        switch self {
        case .preparing:
            String(localized: "Setting up your export options and validating the date range.")
        case .generating:
            String(localized: "Collecting transactions and assembling a shareable file.")
        case .finalizing:
            String(localized: "Saving the export so it can be shared safely.")
        }
    }

    var progressLabel: String {
        switch self {
        case .preparing:
            String(localized: "Step 1 of 3")
        case .generating:
            String(localized: "Step 2 of 3")
        case .finalizing:
            String(localized: "Step 3 of 3")
        }
    }
}

struct ExportProgressView: View {
    let phase: ExportProgressPhase

    var body: some View {
        VCard(shadow: .medium) {
            VStack(alignment: .leading, spacing: VSpacing.md) {
                HStack(alignment: .top, spacing: VSpacing.md) {
                    ZStack {
                        Circle()
                            .fill(VColors.primary.opacity(0.12))
                            .frame(width: 40, height: 40)

                        Image(systemName: "square.and.arrow.up.circle.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(VColors.primary)
                    }

                    VStack(alignment: .leading, spacing: VSpacing.xs) {
                        Text(phase.title)
                            .font(VTypography.title3)
                            .foregroundStyle(VColors.textPrimary)

                        Text(phase.detail)
                            .font(VTypography.caption1)
                            .foregroundStyle(VColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()
                }

                ProgressView(value: phase.progressValue)
                    .tint(VColors.primary)

                HStack {
                    Text(String(localized: "Export in progress"))
                    Spacer()
                    Text(phase.progressLabel)
                }
                .font(VTypography.caption1)
                .foregroundStyle(VColors.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(String(localized: "Export progress")))
        .accessibilityValue(Text("\(phase.title). \(phase.progressLabel)"))
    }
}

#Preview {
    VStack(spacing: VSpacing.lg) {
        ExportProgressView(phase: .preparing)
        ExportProgressView(phase: .generating)
        ExportProgressView(phase: .finalizing)
    }
    .padding(VSpacing.screenPadding)
    .background(VColors.groupedBackground)
}

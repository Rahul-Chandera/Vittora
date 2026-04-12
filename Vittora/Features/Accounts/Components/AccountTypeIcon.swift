import SwiftUI

struct AccountTypeIcon: View {
    let type: AccountType
    var size: CGFloat = 36

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.15))
                .frame(width: size, height: size)
            Image(systemName: iconName)
                .font(.system(size: size * 0.45, weight: .semibold))
                .foregroundColor(color)
        }
    }

    private var iconName: String {
        switch type {
        case .cash:         return "banknote.fill"
        case .bank:         return "building.columns.fill"
        case .creditCard:   return "creditcard.fill"
        case .loan:         return "arrow.up.arrow.down.circle.fill"
        case .digitalWallet: return "iphone.gen2"
        case .investment:   return "chart.line.uptrend.xyaxis"
        case .receivable:   return "arrow.down.circle.fill"
        case .payable:      return "arrow.up.circle.fill"
        }
    }

    private var color: Color {
        switch type {
        case .cash:         return .green
        case .bank:         return VColors.primary
        case .creditCard:   return .orange
        case .loan:         return .red
        case .digitalWallet: return .purple
        case .investment:   return .teal
        case .receivable:   return VColors.income
        case .payable:      return VColors.expense
        }
    }
}

#Preview {
    VStack(spacing: VSpacing.md) {
        ForEach(AccountType.allCases, id: \.self) { type in
            HStack {
                AccountTypeIcon(type: type)
                Text(type.rawValue.capitalized)
                    .font(VTypography.body)
                Spacer()
            }
        }
    }
    .padding(VSpacing.screenPadding)
}

import SwiftUI
import VittoraCore

struct AccountTypeIcon: View {
    let type: AccountType
    var size: CGFloat = 36

    var body: some View {
        ZStack {
            Circle()
                .fill(VColors.iconTintFill(tint))
                .frame(width: size, height: size)
            Image(systemName: iconName)
                .font(.system(size: size * 0.45, weight: .semibold))
                .foregroundStyle(VColors.iconTint(tint))
        }
        // Decorative: every caller pairs this with the type's name, so the tint
        // carries no meaning on its own and needs no contrast guarantee of its
        // own. The tints clear AA anyway.
        .accessibilityHidden(true)
    }

    private var tint: VColors.IconTint {
        switch type {
        case .cash:          return .green
        case .bank:          return .blue
        case .creditCard:    return .red
        case .loan:          return .orange
        case .digitalWallet: return .indigo
        case .investment:    return .purple
        case .receivable:    return .teal
        case .payable:       return .pink
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
}

#Preview {
    VStack(spacing: VSpacing.md) {
        ForEach(AccountType.allCases, id: \.self) { type in
            HStack {
                AccountTypeIcon(type: type)
                Text(type.displayName)
                    .font(VTypography.body)
                Spacer()
            }
        }
    }
    .padding(VSpacing.screenPadding)
}

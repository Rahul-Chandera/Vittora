import WidgetKit
import SwiftUI

@main
struct VittoraWidgetsBundle: WidgetBundle {
    var body: some Widget {
        TodaySpendingWidget()
        BudgetRemainingWidget()
        LockScreenAccessoryWidget()
        QuickLogWidget()
        #if os(iOS)
        ShoppingSessionLiveActivity()
        BillCountdownLiveActivity()
        #endif
    }
}

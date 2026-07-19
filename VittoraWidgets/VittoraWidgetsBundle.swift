import WidgetKit
import SwiftUI

@main
struct VittoraWidgetsBundle: WidgetBundle {
    var body: some Widget {
        TodaySpendingWidget()
        BudgetRemainingWidget()
    }
}

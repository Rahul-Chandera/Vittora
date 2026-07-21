import Foundation
import VittoraCore

struct NotificationSchedulePreferences: Equatable, Sendable {
    nonisolated static let defaultDeliveryMinutes = 9 * 60
    nonisolated static let defaultQuietStartMinutes = 22 * 60
    nonisolated static let defaultQuietEndMinutes = 7 * 60
    nonisolated static let defaultBillLeadDays = 3
    nonisolated static let supportedBillLeadDays = [0, 1, 3]

    nonisolated static func billLeadDays(in userDefaults: UserDefaults) -> Int {
        guard let stored = userDefaults.object(
            forKey: AppUserDefaults.StandardKey.billReminderLeadDays
        ) as? Int, supportedBillLeadDays.contains(stored) else {
            return defaultBillLeadDays
        }
        return stored
    }

    var deliveryMinutes: Int
    var quietHoursEnabled: Bool
    var quietStartMinutes: Int
    var quietEndMinutes: Int

    nonisolated init(userDefaults: UserDefaults) {
        deliveryMinutes = userDefaults.object(
            forKey: AppUserDefaults.StandardKey.notificationDeliveryTime
        ) as? Int ?? Self.defaultDeliveryMinutes
        quietHoursEnabled = userDefaults.bool(
            forKey: AppUserDefaults.StandardKey.notificationQuietHoursEnabled
        )
        quietStartMinutes = userDefaults.object(
            forKey: AppUserDefaults.StandardKey.notificationQuietHoursStart
        ) as? Int ?? Self.defaultQuietStartMinutes
        quietEndMinutes = userDefaults.object(
            forKey: AppUserDefaults.StandardKey.notificationQuietHoursEnd
        ) as? Int ?? Self.defaultQuietEndMinutes
    }

    nonisolated init(
        deliveryMinutes: Int = defaultDeliveryMinutes,
        quietHoursEnabled: Bool = false,
        quietStartMinutes: Int = defaultQuietStartMinutes,
        quietEndMinutes: Int = defaultQuietEndMinutes
    ) {
        self.deliveryMinutes = deliveryMinutes
        self.quietHoursEnabled = quietHoursEnabled
        self.quietStartMinutes = quietStartMinutes
        self.quietEndMinutes = quietEndMinutes
    }

    nonisolated func adjustedFireDate(
        for fireDate: Date,
        category: VittoraNotificationCategory,
        calendar: Calendar
    ) -> Date {
        let deliveryDate = category.usesPreferredDeliveryTime
            ? date(onSameLocalDayAs: fireDate, minutes: deliveryMinutes, calendar: calendar)
            : fireDate

        guard quietHoursEnabled,
              quietStartMinutes != quietEndMinutes,
              isInsideQuietHours(deliveryDate, calendar: calendar)
        else {
            return deliveryDate
        }

        let localMinutes = minutesSinceMidnight(deliveryDate, calendar: calendar)
        let crossesMidnight = quietStartMinutes > quietEndMinutes
        let endDayOffset = crossesMidnight && localMinutes >= quietStartMinutes ? 1 : 0
        let endDay = calendar.date(byAdding: .day, value: endDayOffset, to: deliveryDate) ?? deliveryDate
        return date(onSameLocalDayAs: endDay, minutes: quietEndMinutes, calendar: calendar)
    }

    nonisolated private func isInsideQuietHours(_ date: Date, calendar: Calendar) -> Bool {
        let minutes = minutesSinceMidnight(date, calendar: calendar)
        if quietStartMinutes < quietEndMinutes {
            return minutes >= quietStartMinutes && minutes < quietEndMinutes
        }
        return minutes >= quietStartMinutes || minutes < quietEndMinutes
    }

    nonisolated private func minutesSinceMidnight(_ date: Date, calendar: Calendar) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    nonisolated private func date(onSameLocalDayAs date: Date, minutes: Int, calendar: Calendar) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = minutes / 60
        components.minute = minutes % 60
        components.second = 0
        return calendar.date(from: components) ?? date
    }
}

private extension VittoraNotificationCategory {
    nonisolated var usesPreferredDeliveryTime: Bool {
        switch self {
        case .billDue, .recurring, .debt:
            true
        case .budgetAlert, .goal:
            false
        }
    }
}

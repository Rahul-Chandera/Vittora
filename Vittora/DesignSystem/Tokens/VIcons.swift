import SwiftUI

enum VIcons {
    // MARK: - Tab Bar Icons
    enum TabBar {
        static let dashboard = "chart.pie.fill"
        static let transactions = "list.bullet.rectangle.fill"
        static let budgets = "target"
        static let accounts = "wallet.pass"
        static let settings = "gear"
    }

    // MARK: - Actions
    enum Actions {
        static let add = "plus"
        static let addFilled = "plus.circle.fill"
        static let edit = "pencil"
        static let editFilled = "pencil.circle.fill"
        static let delete = "trash"
        static let deleteFilled = "trash.fill"
        static let search = "magnifyingglass"
        static let filter = "funnel"
        static let filterFilled = "funnel.fill"
        static let sort = "arrow.up.arrow.down"
        static let close = "xmark"
        static let closeFilled = "xmark.circle.fill"
        static let back = "chevron.left"
        static let forward = "chevron.right"
        static let more = "ellipsis"
        static let moreFilled = "ellipsis.circle.fill"
        static let share = "square.and.arrow.up"
        static let download = "arrow.down.circle"
        static let upload = "arrow.up.circle"
    }

    // MARK: - Transaction Types
    enum TransactionTypes {
        static let expense = "arrow.up.right.circle.fill"
        static let income = "arrow.down.left.circle.fill"
        static let transfer = "arrow.left.arrow.right.circle.fill"
        static let recurring = "repeat.circle.fill"
    }

    // MARK: - Account Types
    enum AccountTypes {
        static let checking = "building.2.fill"
        static let savings = "piggybank.fill"
        static let credit = "creditcard.fill"
        static let investment = "chart.line.uptrend.xyaxis"
        static let cash = "dollarsign.circle.fill"
        static let loan = "percent"
    }

    // MARK: - Category Defaults
    enum CategoryIcons {
        static let shopping = "bag.fill"
        static let food = "fork.knife"
        static let transport = "car.fill"
        static let utilities = "lightbulb.fill"
        static let health = "heart.fill"
        static let entertainment = "popcorn.fill"
        static let education = "book.fill"
        static let salary = "banknote.fill"
        static let investment = "chart.line.uptrend.xyaxis"
        static let gifts = "gift.fill"
        static let subscriptions = "repeat.1"
        static let insurance = "shield.fill"
    }

    // MARK: - Status Indicators
    enum Status {
        static let success = "checkmark.circle.fill"
        static let warning = "exclamationmark.circle.fill"
        static let error = "xmark.circle.fill"
        static let info = "info.circle.fill"
        static let pending = "clock.fill"
        static let synced = "checkmark.icloud.fill"
        static let unsynced = "icloud.slash.fill"
    }

    // MARK: - Miscellaneous
    enum Misc {
        static let home = "house.fill"
        static let settings = "gear"
        static let help = "questionmark.circle.fill"
        static let notification = "bell.fill"
        static let notificationOff = "bell.slash.fill"
        static let calendar = "calendar"
        static let clock = "clock"
        static let location = "mappin.circle.fill"
        static let user = "person.circle.fill"
        static let users = "person.2.circle.fill"
        static let link = "link"
        static let attachment = "paperclip"
        static let camera = "camera.fill"
        static let photo = "photo.fill"
        static let globe = "globe"
        static let lock = "lock.fill"
        static let lockOpen = "lock.open.fill"
        static let eye = "eye.fill"
        static let eyeSlash = "eye.slash.fill"
    }

    // MARK: - Helper Function
    static func icon(for iconName: String) -> Image {
        Image(systemName: iconName)
    }
}

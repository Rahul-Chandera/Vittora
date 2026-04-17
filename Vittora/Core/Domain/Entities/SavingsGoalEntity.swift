import Foundation

// MARK: - Goal Category

enum GoalCategory: String, Sendable, Hashable, CaseIterable, Codable {
    case emergency
    case travel
    case vehicle
    case home
    case education
    case retirement
    case wedding
    case gadget
    case health
    case other

    var displayName: String {
        switch self {
        case .emergency:  return String(localized: "Emergency Fund")
        case .travel:     return String(localized: "Travel")
        case .vehicle:    return String(localized: "Vehicle")
        case .home:       return String(localized: "Home")
        case .education:  return String(localized: "Education")
        case .retirement: return String(localized: "Retirement")
        case .wedding:    return String(localized: "Wedding")
        case .gadget:     return String(localized: "Gadget")
        case .health:     return String(localized: "Health")
        case .other:      return String(localized: "Other")
        }
    }

    var systemImage: String {
        switch self {
        case .emergency:  return "shield.fill"
        case .travel:     return "airplane"
        case .vehicle:    return "car.fill"
        case .home:       return "house.fill"
        case .education:  return "graduationcap.fill"
        case .retirement: return "figure.walk"
        case .wedding:    return "heart.fill"
        case .gadget:     return "laptopcomputer"
        case .health:     return "cross.case.fill"
        case .other:      return "star.fill"
        }
    }
}

// MARK: - Goal Status

enum GoalStatus: String, Sendable, Hashable, Codable {
    case active
    case achieved
    case paused
    case cancelled

    var displayName: String {
        switch self {
        case .active:    return String(localized: "Active")
        case .achieved:  return String(localized: "Achieved")
        case .paused:    return String(localized: "Paused")
        case .cancelled: return String(localized: "Cancelled")
        }
    }
}

// MARK: - Savings Goal Entity

struct SavingsGoalEntity: Identifiable, Hashable, Equatable, Sendable {
    let id: UUID
    var name: String
    var category: GoalCategory
    var targetAmount: Decimal
    var currentAmount: Decimal
    var targetDate: Date?
    var linkedAccountID: UUID?
    var note: String?
    var status: GoalStatus
    var colorHex: String
    var createdAt: Date
    var updatedAt: Date

    // MARK: - Computed

    var remainingAmount: Decimal { max(0, targetAmount - currentAmount) }

    var progressFraction: Double {
        guard targetAmount > 0 else { return 0 }
        return min(1.0, (currentAmount as NSDecimalNumber).doubleValue / (targetAmount as NSDecimalNumber).doubleValue)
    }

    var progressPercent: Double { progressFraction * 100 }

    var isAchieved: Bool { currentAmount >= targetAmount }

    var daysRemaining: Int? {
        guard let date = targetDate, status == .active else { return nil }
        return Calendar.current.dateComponents([.day], from: .now, to: date).day
    }

    var isOverdue: Bool {
        guard let days = daysRemaining else { return false }
        return days < 0 && !isAchieved
    }

    /// Monthly savings needed to hit the target by the deadline
    var monthlySavingsNeeded: Decimal? {
        guard let days = daysRemaining, days > 0, remainingAmount > 0 else { return nil }
        let months = Decimal(max(1, days / 30))
        let raw = remainingAmount / months
        var result = Decimal()
        var copy = raw
        NSDecimalRound(&result, &copy, 2, .bankers)
        return result
    }

    nonisolated init(
        id: UUID = UUID(),
        name: String,
        category: GoalCategory = .other,
        targetAmount: Decimal,
        currentAmount: Decimal = 0,
        targetDate: Date? = nil,
        linkedAccountID: UUID? = nil,
        note: String? = nil,
        status: GoalStatus = .active,
        colorHex: String = "#5856D6",
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.targetAmount = targetAmount
        self.currentAmount = currentAmount
        self.targetDate = targetDate
        self.linkedAccountID = linkedAccountID
        self.note = note
        self.status = status
        self.colorHex = colorHex
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Progress Summary

struct GoalProgressSummary: Sendable {
    let totalGoals: Int
    let activeGoals: Int
    let achievedGoals: Int
    let totalTargetAmount: Decimal
    let totalSavedAmount: Decimal
    var overallProgressFraction: Double {
        guard totalTargetAmount > 0 else { return 0 }
        return min(1.0, (totalSavedAmount as NSDecimalNumber).doubleValue /
                        (totalTargetAmount as NSDecimalNumber).doubleValue)
    }
}

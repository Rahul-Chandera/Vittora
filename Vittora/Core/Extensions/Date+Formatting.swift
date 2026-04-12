import Foundation

extension Date {
    enum DateFormatStyle {
        case relative
        case short
        case medium
        case long
        case monthYear
        case yearOnly
        case time
        case custom(String)

        var formatString: String {
            switch self {
            case .relative:
                return "relative"
            case .short:
                return "MM/dd/yy"
            case .medium:
                return "MMM d, yyyy"
            case .long:
                return "MMMM d, yyyy"
            case .monthYear:
                return "MMMM yyyy"
            case .yearOnly:
                return "yyyy"
            case .time:
                return "h:mm a"
            case .custom(let format):
                return format
            }
        }
    }

    /// Format date using predefined or custom format styles.
    ///
    /// - Parameter style: Format style to use
    /// - Returns: Formatted date string
    func formatted(as style: DateFormatStyle) -> String {
        if style == .relative {
            return relativeFormatted()
        }

        let formatter = DateFormatter()
        formatter.dateFormat = style.formatString
        formatter.locale = Locale.current
        return formatter.string(from: self)
    }

    /// Get relative date string (e.g., "2 hours ago", "Tomorrow", "Last week")
    private func relativeFormatted() -> String {
        let calendar = Calendar.current
        let now = Date()

        let components = calendar.dateComponents([.second, .minute, .hour, .day, .weekOfYear, .month, .year], from: self, to: now)

        if let year = components.year, year > 0 {
            return year == 1 ? "1 year ago" : "\(year) years ago"
        }
        if let month = components.month, month > 0 {
            return month == 1 ? "1 month ago" : "\(month) months ago"
        }
        if let week = components.weekOfYear, week > 0 {
            return week == 1 ? "1 week ago" : "\(week) weeks ago"
        }
        if let day = components.day {
            switch day {
            case 0:
                if let hour = components.hour {
                    return hour == 1 ? "1 hour ago" : "\(hour) hours ago"
                }
                if let minute = components.minute {
                    return minute == 1 ? "1 minute ago" : "\(minute) minutes ago"
                }
                return "Just now"
            case 1:
                return "Yesterday"
            default:
                return "\(day) days ago"
            }
        }

        return formatted(as: .medium)
    }

    /// Check if date is today
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }

    /// Check if date is yesterday
    var isYesterday: Bool {
        Calendar.current.isDateInYesterday(self)
    }

    /// Check if date is tomorrow
    var isTomorrow: Bool {
        Calendar.current.isDateInTomorrow(self)
    }

    /// Check if date is in the past
    var isPast: Bool {
        self < Date()
    }

    /// Check if date is in the future
    var isFuture: Bool {
        self > Date()
    }

    /// Get the start of the day
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    /// Get the end of the day
    var endOfDay: Date {
        Calendar.current.date(byAdding: DateComponents(day: 1, second: -1), to: startOfDay) ?? self
    }

    /// Get the start of the month
    var startOfMonth: Date {
        let components = Calendar.current.dateComponents([.year, .month], from: self)
        return Calendar.current.date(from: components) ?? self
    }

    /// Get the end of the month
    var endOfMonth: Date {
        let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: startOfMonth) ?? self
        return Calendar.current.date(byAdding: .second, value: -1, to: nextMonth) ?? self
    }

    /// Get the start of the year
    var startOfYear: Date {
        let components = Calendar.current.dateComponents([.year], from: self)
        return Calendar.current.date(from: components) ?? self
    }

    /// Get the end of the year
    var endOfYear: Date {
        let nextYear = Calendar.current.date(byAdding: .year, value: 1, to: startOfYear) ?? self
        return Calendar.current.date(byAdding: .second, value: -1, to: nextYear) ?? self
    }

    /// Get the next occurrence of a given weekday
    ///
    /// - Parameter weekday: Weekday to find (1=Sunday, 2=Monday, ..., 7=Saturday)
    /// - Returns: Date of next occurrence
    func nextOccurrence(of weekday: Int) -> Date {
        var dateComponent = DateComponents()
        dateComponent.day = (weekday - Calendar.current.component(.weekday, from: self) + 7) % 7
        if dateComponent.day ?? 0 == 0 {
            dateComponent.day = 7
        }
        return Calendar.current.date(byAdding: dateComponent, to: self) ?? self
    }

    /// Check if date is within the same week as another date
    func isInSameWeek(as other: Date) -> Bool {
        Calendar.current.isDate(self, equalTo: other, toGranularity: .weekOfYear)
    }

    /// Check if date is within the same month as another date
    func isInSameMonth(as other: Date) -> Bool {
        Calendar.current.isDate(self, equalTo: other, toGranularity: .month)
    }

    /// Check if date is within the same year as another date
    func isInSameYear(as other: Date) -> Bool {
        Calendar.current.isDate(self, equalTo: other, toGranularity: .year)
    }

    /// Get number of days between this date and another date
    func daysBetween(_ other: Date) -> Int {
        let components = Calendar.current.dateComponents([.day], from: self, to: other)
        return components.day ?? 0
    }
}

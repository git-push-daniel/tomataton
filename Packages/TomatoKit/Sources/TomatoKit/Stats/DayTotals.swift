import Foundation

/// Totals for one calendar day.
public struct DayTotals: Identifiable, Equatable, Sendable {
    public var day: DateInterval
    public var totals: Totals

    public var id: Date { day.start }

    public init(day: DateInterval, totals: Totals) {
        self.day = day
        self.totals = totals
    }
}

extension Totals {
    /// One entry per calendar day overlapping `interval`, in order, including
    /// days without sessions. Day boundaries come from `calendar`, so days
    /// that are 23 or 25 hours long around DST changes are handled correctly.
    public static func daily(
        _ records: [SessionRecord], in interval: DateInterval, calendar: Calendar
    ) -> [DayTotals] {
        var days: [DayTotals] = []
        var cursor = calendar.startOfDay(for: interval.start)
        while cursor < interval.end, let day = calendar.dateInterval(of: .day, for: cursor) {
            days.append(DayTotals(day: day, totals: Totals(records, in: day)))
            cursor = day.end
        }
        return days
    }
}

extension Calendar {
    /// The week containing `date`, starting on the calendar's first weekday.
    public func week(containing date: Date) -> DateInterval? {
        dateInterval(of: .weekOfYear, for: date)
    }
}

import Foundation

/// Worked/rested time and completed pomodoros within a time interval (e.g. a day).
public struct Totals: Equatable, Sendable {
    public var worked: TimeInterval = 0
    public var rested: TimeInterval = 0
    /// Completed focus sessions, counted on the day they ended.
    public var pomodoros = 0

    public init() {}

    public init(_ records: some Sequence<SessionRecord>, in interval: DateInterval) {
        for record in records { add(record, in: interval) }
    }

    /// Adds the part of `record` that falls inside `interval`. A session that
    /// straddles a boundary (e.g. midnight) contributes its active time in
    /// proportion to its wall-clock overlap.
    public mutating func add(_ record: SessionRecord, in interval: DateInterval) {
        let seconds = TimeInterval(record.activeSeconds) * record.share(of: interval)
        if record.phase.isRest { rested += seconds } else { worked += seconds }
        if record.phase == .work, record.outcome == .completed, interval.containsHalfOpen(record.endedAt) {
            pomodoros += 1
        }
    }
}

extension SessionRecord {
    /// Fraction (0...1) of this session's wall-clock span inside `interval`.
    func share(of interval: DateInterval) -> Double {
        let span = endedAt.timeIntervalSince(startedAt)
        guard span > 0 else { return interval.containsHalfOpen(startedAt) ? 1 : 0 }
        let overlap = min(endedAt, interval.end).timeIntervalSince(max(startedAt, interval.start))
        return max(0, overlap) / span
    }
}

extension DateInterval {
    /// `[start, end)` — unlike `contains(_:)`, adjacent days never both claim midnight.
    func containsHalfOpen(_ date: Date) -> Bool {
        date >= start && date < end
    }
}

import Foundation

/// Plausible fake history for trying out the stats screen. Every record is
/// tagged `SampleHistory.tag` so it can be removed again without touching
/// real sessions.
public enum SampleHistory {
    public static let tag = "sample"

    /// Sessions on the days in `days` before `now` (today included, up to
    /// `now`). Deterministic for a given `seed`.
    public static func generate(
        days: Int, endingAt now: Date, calendar: Calendar, seed: UInt64 = 42
    ) -> [SessionRecord] {
        var rng = SplitMix64(seed: seed)
        var records: [SessionRecord] = []
        let today = calendar.startOfDay(for: now)

        for offset in (0..<days).reversed() {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let isWeekend = calendar.isDateInWeekend(day)
            // Some days off, more of them at weekends.
            if Double.random(in: 0..<1, using: &rng) < (isWeekend ? 0.6 : 0.12) { continue }

            let pomodoros = Int.random(in: isWeekend ? 1...4 : 3...11, using: &rng)
            let startMinute = Int.random(in: (8 * 60)...(10 * 60 + 30), using: &rng)
            var clock = day.addingTimeInterval(TimeInterval(startMinute * 60))

            for index in 0..<pomodoros {
                // Mostly full 25-minute sessions; now and then cut short.
                let cutShort = Double.random(in: 0..<1, using: &rng) < 0.15
                let workSeconds = cutShort ? Int.random(in: 5...20, using: &rng) * 60 : 1500
                guard append(.work, seconds: workSeconds, planned: 1500,
                             outcome: cutShort ? .stopped : .completed,
                             at: &clock, now: now, to: &records) else { return records }

                let isLongBreak = (index + 1) % 4 == 0
                let breakSeconds = isLongBreak ? 900 : 300
                guard index < pomodoros - 1,
                      append(isLongBreak ? .longBreak : .shortBreak, seconds: breakSeconds, planned: breakSeconds,
                             outcome: .completed, at: &clock, now: now, to: &records)
                else { continue }
                // Occasionally wander off for a while after a break.
                if Double.random(in: 0..<1, using: &rng) < 0.2 {
                    clock += TimeInterval(Int.random(in: 10...90, using: &rng) * 60)
                }
            }
        }
        return records
    }

    /// Appends one session starting at `clock` and advances it. Returns false
    /// (appending nothing) once sessions would run past `now`.
    private static func append(
        _ phase: Phase, seconds: Int, planned: Int, outcome: SessionRecord.Outcome,
        at clock: inout Date, now: Date, to records: inout [SessionRecord]
    ) -> Bool {
        let end = clock.addingTimeInterval(TimeInterval(seconds))
        guard end <= now else { return false }
        records.append(SessionRecord(
            phase: phase, startedAt: clock, endedAt: end, plannedSeconds: planned,
            activeSeconds: seconds, outcome: outcome, presetName: "Classic", tag: tag
        ))
        clock = end
        return true
    }
}

/// Small seedable generator so sample data is reproducible.
struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

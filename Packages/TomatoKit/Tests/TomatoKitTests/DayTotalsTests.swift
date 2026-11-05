import Foundation
import Testing
@testable import TomatoKit

@Suite struct DayTotalsTests {
    private func calendar(_ timeZone: String, firstWeekday: Int = 2) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZone)!
        calendar.firstWeekday = firstWeekday
        return calendar
    }

    private func date(_ calendar: Calendar, _ day: Int, _ hour: Int = 0, _ minute: Int = 0, month: Int = 11) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
    }

    private func work(_ start: Date, minutes: Double, outcome: SessionRecord.Outcome = .completed) -> SessionRecord {
        SessionRecord(phase: .work, startedAt: start, endedAt: start.addingTimeInterval(minutes * 60),
                      plannedSeconds: Int(minutes * 60), activeSeconds: Int(minutes * 60),
                      outcome: outcome, presetName: "Test")
    }

    @Test func weekStartsOnCalendarsFirstWeekday() throws {
        let thursday = date(calendar("UTC"), 5, 12)
        let mondayWeek = try #require(calendar("UTC", firstWeekday: 2).week(containing: thursday))
        let sundayWeek = try #require(calendar("UTC", firstWeekday: 1).week(containing: thursday))

        #expect(mondayWeek.start == date(calendar("UTC"), 2))
        #expect(sundayWeek.start == date(calendar("UTC"), 1))
        #expect(mondayWeek.duration == 7 * 86_400)
    }

    @Test func oneEntryPerDayIncludingEmptyDays() throws {
        let cal = calendar("UTC")
        let week = try #require(cal.week(containing: date(cal, 5)))
        let records = [
            work(date(cal, 3, 9), minutes: 25),
            work(date(cal, 3, 10), minutes: 25),
            work(date(cal, 6, 14), minutes: 10, outcome: .stopped),
        ]
        let days = Totals.daily(records, in: week, calendar: cal)

        #expect(days.count == 7)
        #expect(days.map { cal.component(.day, from: $0.day.start) } == [2, 3, 4, 5, 6, 7, 8])
        #expect(days.map(\.totals.pomodoros) == [0, 2, 0, 0, 0, 0, 0])
        #expect(days.map(\.totals.worked) == [0, 3000, 0, 0, 600, 0, 0])
    }

    @Test func sessionOverMidnightIsSplitBetweenDays() throws {
        let cal = calendar("UTC")
        let week = try #require(cal.week(containing: date(cal, 5)))
        let days = Totals.daily([work(date(cal, 4, 23, 50), minutes: 20)], in: week, calendar: cal)

        #expect(days[2].totals.worked == 600)  // Wednesday 4th
        #expect(days[3].totals.worked == 600)  // Thursday 5th
        #expect(days[3].totals.pomodoros == 1)
    }

    @Test func daylightSavingWeekHasOneLongDay() throws {
        // Clocks go back on Sunday 25 October 2026 in Europe.
        let cal = calendar("Europe/Bucharest")
        let week = try #require(cal.week(containing: date(cal, 22, month: 10)))
        let days = Totals.daily([], in: week, calendar: cal)

        #expect(days.count == 7)
        #expect(days.last?.day.duration == TimeInterval(25 * 3600))
        #expect(days.dropLast().allSatisfy { $0.day.duration == 24 * 3600 })
        #expect(days.last?.day.end == week.end)
    }
}

@Suite struct SampleHistoryTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }()
    private var now: Date { calendar.date(from: DateComponents(year: 2026, month: 11, day: 5, hour: 15))! }

    @Test func isDeterministicPerSeed() {
        let a = SampleHistory.generate(days: 21, endingAt: now, calendar: calendar)
        let b = SampleHistory.generate(days: 21, endingAt: now, calendar: calendar)
        let c = SampleHistory.generate(days: 21, endingAt: now, calendar: calendar, seed: 7)
        #expect(a.withoutIDs == b.withoutIDs)
        #expect(a.withoutIDs != c.withoutIDs)
    }

    @Test func producesTaggedNonOverlappingPastSessions() {
        let records = SampleHistory.generate(days: 21, endingAt: now, calendar: calendar)
        let earliest = calendar.date(byAdding: .day, value: -20, to: calendar.startOfDay(for: now))!

        #expect(records.count > 50)
        #expect(records.allSatisfy { $0.tag == SampleHistory.tag })
        #expect(records.allSatisfy { $0.startedAt >= earliest && $0.endedAt <= now })
        #expect(records.allSatisfy { $0.activeSeconds == Int($0.endedAt.timeIntervalSince($0.startedAt)) })
        for (previous, next) in zip(records, records.dropFirst()) {
            #expect(previous.endedAt <= next.startedAt)
        }
        #expect(Set(records.map(\.phase)) == Set(Phase.allCases))
    }

    @Test func canBeRemovedWithoutTouchingRealSessions() throws {
        let store = try HistoryStore.inMemory()
        let real = SessionRecord(phase: .work, startedAt: now.addingTimeInterval(-1500), endedAt: now,
                                 plannedSeconds: 1500, activeSeconds: 1500, outcome: .completed,
                                 presetName: "Classic")
        let samples = SampleHistory.generate(days: 7, endingAt: now.addingTimeInterval(-1500), calendar: calendar)
        try store.insert(samples + [real])

        #expect(try store.deleteRecords(tagged: SampleHistory.tag) == samples.count)
        #expect(try store.records(in: DateInterval(start: .distantPast, end: .distantFuture)) == [real])
    }
}

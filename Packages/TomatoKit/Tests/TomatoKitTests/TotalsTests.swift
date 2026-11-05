import Foundation
import Testing
@testable import TomatoKit

@Suite struct TotalsTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }()

    private var midnight: Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: 6))!
    }

    private func day(containing date: Date) -> DateInterval {
        calendar.dateInterval(of: .day, for: date)!
    }

    private func record(
        _ phase: Phase, from start: TimeInterval, to end: TimeInterval,
        active: Int? = nil, outcome: SessionRecord.Outcome = .completed
    ) -> SessionRecord {
        SessionRecord(
            phase: phase,
            startedAt: midnight.addingTimeInterval(start),
            endedAt: midnight.addingTimeInterval(end),
            plannedSeconds: Int(end - start),
            activeSeconds: active ?? Int(end - start),
            outcome: outcome,
            presetName: "Test"
        )
    }

    private var today: DateInterval { day(containing: midnight) }
    private var yesterday: DateInterval { day(containing: midnight.addingTimeInterval(-1)) }

    @Test func emptyIsZero() {
        #expect(Totals([], in: today) == Totals())
    }

    @Test func separatesWorkFromRest() {
        let totals = Totals([
            record(.work, from: minutes(60), to: minutes(85)),
            record(.shortBreak, from: minutes(85), to: minutes(90)),
            record(.work, from: minutes(90), to: minutes(115)),
            record(.longBreak, from: minutes(115), to: minutes(130)),
        ], in: today)

        #expect(totals.worked == minutes(50))
        #expect(totals.rested == minutes(20))
        #expect(totals.pomodoros == 2)
    }

    @Test func ignoresSessionsOnOtherDays() {
        let records = [record(.work, from: -minutes(120), to: -minutes(95))]
        #expect(Totals(records, in: today) == Totals())
        #expect(Totals(records, in: yesterday).worked == minutes(25))
    }

    @Test func splitsSessionAcrossMidnight() {
        let records = [record(.work, from: -minutes(10), to: minutes(10))]

        #expect(Totals(records, in: yesterday).worked == minutes(10))
        #expect(Totals(records, in: today).worked == minutes(10))
        // The pomodoro belongs to the day it finished.
        #expect(Totals(records, in: yesterday).pomodoros == 0)
        #expect(Totals(records, in: today).pomodoros == 1)
    }

    @Test func splitIsProportionalToWallClockWhenPaused() {
        // 30 min on the clock, 20 of them active.
        let records = [record(.work, from: -minutes(20), to: minutes(10), active: 1200)]
        #expect(Totals(records, in: yesterday).worked == 800)
        #expect(Totals(records, in: today).worked == 400)
    }

    @Test func sessionEndingExactlyAtMidnightBelongsToEarlierDay() {
        let records = [record(.work, from: -minutes(25), to: 0)]
        #expect(Totals(records, in: yesterday).worked == minutes(25))
        #expect(Totals(records, in: today).worked == 0)
        // …except its pomodoro, which is counted when it ended: at 00:00 today.
        #expect(Totals(records, in: today).pomodoros == 1)
        #expect(Totals(records, in: yesterday).pomodoros == 0)
    }

    @Test func onlyCompletedWorkCountsAsPomodoro() {
        let totals = Totals([
            record(.work, from: 0, to: minutes(10), outcome: .skipped),
            record(.work, from: minutes(10), to: minutes(20), outcome: .stopped),
            record(.work, from: minutes(20), to: minutes(30), outcome: .restarted),
            record(.shortBreak, from: minutes(30), to: minutes(35)),
        ], in: today)

        #expect(totals.pomodoros == 0)
        #expect(totals.worked == minutes(30))
    }

    @Test func liveRecordFromStateCountsTowardTotals() {
        var engine = TimerEngine(preset: testPreset)
        engine.start(now: midnight.addingTimeInterval(minutes(60)))
        let now = midnight.addingTimeInterval(minutes(64))
        let live = engine.state.record(endingAt: now, outcome: .stopped)

        let totals = Totals([live].compactMap { $0 }, in: today)
        #expect(totals.worked == minutes(4))
        #expect(totals.pomodoros == 0)
    }
}

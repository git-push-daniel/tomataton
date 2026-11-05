import Foundation
import Testing
@testable import TomatoKit

/// End-to-end runs through whole cycles, the way the app drives the engine.
@Suite struct TimerScenarioTests {
    /// As long as ticks come within the auto-start grace period, how often
    /// the app ticks doesn't change what gets recorded.
    @Test func tickGranularityDoesNotChangeOutcome() {
        var everySecond = TimerEngine(preset: nonstopPreset)
        var everyFewMinutes = TimerEngine(preset: nonstopPreset)
        everySecond.start(now: at(0))
        everyFewMinutes.start(now: at(0))

        let end = minutes(120)
        var fine: [SessionRecord] = []
        for second in stride(from: 1.0, through: end, by: 1) {
            fine += everySecond.tick(now: at(second))
        }
        var coarse: [SessionRecord] = []
        for second in stride(from: TimerEngine.autoStartGrace, through: end, by: TimerEngine.autoStartGrace) {
            coarse += everyFewMinutes.tick(now: at(second))
        }

        #expect(fine.count == 18)  // 4 sets of 4 phases (27 min each) + work 108–118 + break 118–120
        #expect(fine.withoutIDs == coarse.withoutIDs)
        #expect(everySecond.state == everyFewMinutes.state)
    }

    @Test func classicDayWithPauseAddsUpToActiveTime() {
        var engine = TimerEngine(preset: .classic)  // 25/5/15 × 4, breaks auto-start
        var records: [SessionRecord] = []

        engine.start(now: at(0))
        records += engine.tick(now: at(minutes(30)))  // work 1 (0–25) + break (25–30)
        engine.resume(now: at(minutes(31)))           // back a minute late
        engine.pause(now: at(minutes(41)))            // 2-minute interruption
        engine.resume(now: at(minutes(43)))
        records += engine.tick(now: at(minutes(63)))  // work 2 (31–58) + break (58–63)
        engine.resume(now: at(minutes(63)))
        records += engine.tick(now: at(minutes(93)))  // work 3 (63–88) + break (88–93)
        engine.resume(now: at(minutes(93)))
        records += engine.tick(now: at(minutes(118))) // work 4 (93–118)
        records += engine.tick(now: at(minutes(133))) // long break (118–133)

        #expect(records.phases == [
            .work, .shortBreak, .work, .shortBreak, .work, .shortBreak, .work, .longBreak,
        ])
        #expect(records.allSatisfy { $0.outcome == .completed })
        #expect(records[2].endedAt.timeIntervalSince(records[2].startedAt) == minutes(27))
        #expect(records[2].activeSeconds == 1500)

        let day = DateInterval(start: at(-minutes(60)), duration: 86_400)
        let totals = Totals(records, in: day)
        #expect(totals.worked == minutes(100))
        #expect(totals.rested == minutes(30))
        #expect(totals.pomodoros == 4)

        #expect(engine.state.phase == .work)
        #expect(engine.state.round == 1)
        #expect(engine.state.status == .ready)
    }

    @Test func choppyUsageNeverLosesOrInventsTime() {
        var engine = TimerEngine(preset: testPreset)
        var records: [SessionRecord] = []
        var clock: TimeInterval = 0
        func advance(_ seconds: TimeInterval) { clock += seconds; records += engine.tick(now: at(clock)) }

        engine.start(now: at(clock))
        advance(minutes(3))
        engine.pause(now: at(clock))
        advance(minutes(10))                           // paused: counts nothing
        engine.resume(now: at(clock))
        engine.adjust(by: minutes(1), now: at(clock))
        advance(minutes(2))
        records += engine.restartPhase(now: at(clock)) // 5 min of work, restarted
        advance(minutes(10))                           // work completes
        advance(minutes(1))
        records += engine.skip(now: at(clock))         // 1 min of break, skipped
        advance(minutes(4))
        records += engine.stop(now: at(clock))         // 4 min of work, stopped

        #expect(records.outcomes == [.restarted, .completed, .skipped, .stopped])
        #expect(records.map(\.activeSeconds) == [300, 600, 60, 240])

        let totals = Totals(records, in: DateInterval(start: t0, duration: 86_400))
        #expect(totals.worked == minutes(19))
        #expect(totals.rested == minutes(1))
        #expect(totals.pomodoros == 1)
    }
}

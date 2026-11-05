import Foundation
import Testing
@testable import TomatoKit

@Suite struct LifecycleTests {
    @Test func freshEngineIsReadyOnFirstWorkRound() {
        let engine = TimerEngine(preset: testPreset)
        #expect(engine.state.status == .ready)
        #expect(engine.state.phase == .work)
        #expect(engine.state.round == 1)
        #expect(engine.state.remaining(at: t0) == minutes(10))
    }

    @Test func toggleStartsReadyPhase() {
        var engine = TimerEngine(preset: testPreset)
        engine.toggle(now: at(0))
        #expect(engine.state.status == .running)
        #expect(engine.state.phaseStartedAt == at(0))
    }

    @Test func pauseExcludesPausedTime() {
        var engine = TimerEngine(preset: testPreset)
        engine.start(now: at(0))
        engine.pause(now: at(minutes(3)))
        #expect(engine.state.remaining(at: at(minutes(60))) == minutes(7))
        engine.resume(now: at(minutes(60)))
        #expect(engine.state.remaining(at: at(minutes(61))) == minutes(6))
    }

    @Test func pausingTwiceIsNoOp() {
        var engine = TimerEngine(preset: testPreset)
        engine.start(now: at(0))
        engine.pause(now: at(minutes(3)))
        engine.pause(now: at(minutes(5)))
        #expect(engine.state.remaining(at: at(minutes(5))) == minutes(7))
    }

    @Test func resumingWhileRunningDoesNotResetClock() {
        var engine = TimerEngine(preset: testPreset)
        engine.start(now: at(0))
        engine.resume(now: at(minutes(4)))
        #expect(engine.state.remaining(at: at(minutes(4))) == minutes(6))
    }

    @Test func pauseAndResumeKeepRoundAndPhase() {
        var engine = TimerEngine(preset: testPreset)
        engine.start(now: at(0))
        engine.tick(now: at(minutes(12)))  // work 1 + short break done
        engine.resume(now: at(minutes(12)))
        engine.adjust(by: -minutes(5), now: at(minutes(13)))

        var clock = minutes(14)
        for phase in [Phase.work, .longBreak] {
            #expect(engine.state.phase == phase)
            let round = engine.state.round
            let remaining = engine.state.remaining(at: at(clock))
            engine.toggle(now: at(clock))
            #expect(engine.state.status == .paused)
            #expect(engine.state.phase == phase)
            #expect(engine.state.round == round)
            clock += minutes(6)
            #expect(engine.state.remaining(at: at(clock)) == remaining)
            engine.toggle(now: at(clock))
            #expect(engine.state.status == .running)
            #expect(engine.state.round == round)
            engine.skip(now: at(clock))
        }
    }

    @Test func endsAtIsOnlyKnownWhileRunning() {
        var engine = TimerEngine(preset: testPreset)
        #expect(engine.state.endsAt == nil)
        engine.start(now: at(0))
        #expect(engine.state.endsAt == at(minutes(10)))
        engine.pause(now: at(minutes(4)))
        #expect(engine.state.endsAt == nil)
        engine.resume(now: at(minutes(6)))
        #expect(engine.state.endsAt == at(minutes(12)))
    }

    @Test func startWithPresetAbandonsCurrentPhase() {
        var engine = TimerEngine(preset: testPreset)
        engine.start(now: at(0))
        let records = engine.start(preset: .quick, now: at(minutes(2)))

        #expect(records.outcomes == [.stopped])
        #expect(engine.state.preset == .quick)
        #expect(engine.state.status == .running)
        #expect(engine.state.remaining(at: at(minutes(2))) == minutes(15))
    }

    @Test func selectPresetWhileRunningRecordsAndWaits() {
        var engine = TimerEngine(preset: testPreset)
        engine.start(now: at(0))
        let records = engine.select(preset: .quick, now: at(minutes(2)))

        #expect(records.outcomes == [.stopped])
        #expect(records.first?.activeSeconds == 120)
        #expect(engine.state == .fresh(.quick))
    }

    @Test func stoppingWithinASecondRecordsNothing() {
        var engine = TimerEngine(preset: testPreset)
        engine.start(now: at(0))
        #expect(engine.stop(now: at(0.4)).isEmpty)
    }
}

@Suite struct CompletionTests {
    @Test func completingWorkAutoStartsBreakAtExactEndTime() {
        var engine = TimerEngine(preset: testPreset)
        engine.start(now: at(0))
        let records = engine.tick(now: at(minutes(10.5)))

        #expect(records.count == 1)
        #expect(records[0].phase == .work)
        #expect(records[0].outcome == .completed)
        #expect(records[0].activeSeconds == 600)
        #expect(records[0].endedAt == at(minutes(10)))

        #expect(engine.state.phase == .shortBreak)
        #expect(engine.state.status == .running)
        #expect(engine.state.remaining(at: at(minutes(10.5))) == minutes(1.5))
    }

    @Test func tickJustBeforeEndDoesNothing() {
        var engine = TimerEngine(preset: testPreset)
        engine.start(now: at(0))
        #expect(engine.tick(now: at(minutes(10) - 1)).isEmpty)
        #expect(engine.state.phase == .work)
    }

    @Test func tickExactlyAtEndCompletes() {
        var engine = TimerEngine(preset: testPreset)
        engine.start(now: at(0))
        #expect(engine.tick(now: at(minutes(10))).outcomes == [.completed])
    }

    @Test func tickWhilePausedOrReadyNeverCompletes() {
        var engine = TimerEngine(preset: testPreset)
        #expect(engine.tick(now: at(minutes(120))).isEmpty)

        engine.start(now: at(0))
        engine.pause(now: at(minutes(5)))
        #expect(engine.tick(now: at(minutes(120))).isEmpty)
        #expect(engine.state.status == .paused)
        #expect(engine.state.remaining(at: at(minutes(120))) == minutes(5))
    }

    @Test func completedRecordSpansWallClockButCountsActiveTime() {
        var engine = TimerEngine(preset: testPreset)
        engine.start(now: at(0))
        engine.pause(now: at(minutes(2)))
        engine.resume(now: at(minutes(5)))
        let records = engine.tick(now: at(minutes(13)))

        #expect(records.count == 1)
        #expect(records[0].startedAt == at(0))
        #expect(records[0].endedAt == at(minutes(13)))
        #expect(records[0].activeSeconds == 600)
    }

    @Test func breakEndingWaitsForUserWhenWorkDoesNotAutoStart() {
        var engine = TimerEngine(preset: testPreset)
        engine.start(now: at(0))
        let records = engine.tick(now: at(minutes(30)))

        #expect(records.phases == [.work, .shortBreak])
        #expect(engine.state.phase == .work)
        #expect(engine.state.round == 2)
        #expect(engine.state.status == .ready)
    }

    @Test func manualPresetWaitsAfterWorkToo() {
        var engine = TimerEngine(preset: manualPreset)
        engine.start(now: at(0))
        #expect(engine.tick(now: at(minutes(11))).phases == [.work])
        #expect(engine.state.phase == .shortBreak)
        #expect(engine.state.status == .ready)
        #expect(engine.state.remaining(at: at(minutes(11))) == minutes(2))
    }

    @Test func longBreakAfterLastRoundThenNewSet() {
        var engine = TimerEngine(preset: testPreset)
        engine.start(now: at(0))
        engine.tick(now: at(minutes(12)))  // work 1 + short break done
        engine.resume(now: at(minutes(12)))
        engine.tick(now: at(minutes(22)))  // work 2 done

        #expect(engine.state.phase == .longBreak)
        engine.tick(now: at(minutes(27)))
        #expect(engine.state.phase == .work)
        #expect(engine.state.round == 1)
    }

    @Test func nonstopChainsPhasesBackToBackAfterLongGap() {
        var engine = TimerEngine(preset: nonstopPreset)
        engine.start(now: at(0))
        let records = engine.tick(now: at(minutes(40)))

        // 0–10 work, 10–12 short, 12–22 work, 22–27 long, 27–37 work, 37–39 short, 39– work (live)
        #expect(records.phases == [.work, .shortBreak, .work, .longBreak, .work, .shortBreak])
        #expect(records.allSatisfy { $0.outcome == .completed && $0.activeSeconds == $0.plannedSeconds })
        for (previous, next) in zip(records, records.dropFirst()) {
            #expect(previous.endedAt == next.startedAt)
        }
        #expect(engine.state.phase == .work)
        #expect(engine.state.round == 2)
        #expect(engine.state.remaining(at: at(minutes(40))) == minutes(9))
    }
}

@Suite struct SkipRestartStopTests {
    @Test func skipRecordsPartialAndKeepsRunning() {
        var engine = TimerEngine(preset: testPreset)
        engine.start(now: at(0))
        let records = engine.skip(now: at(minutes(4)))

        #expect(records.outcomes == [.skipped])
        #expect(records.first?.activeSeconds == 240)
        #expect(engine.state.phase == .shortBreak)
        #expect(engine.state.status == .running)
    }

    @Test func skipWhileReadyRecordsNothing() {
        var engine = TimerEngine(preset: testPreset)
        #expect(engine.skip(now: at(0)).isEmpty)
        #expect(engine.state.phase == .shortBreak)
        #expect(engine.state.status == .ready)
    }

    @Test func skipWhilePausedRecordsPartialAndWaits() {
        var engine = TimerEngine(preset: testPreset)
        engine.start(now: at(0))
        engine.pause(now: at(minutes(3)))
        let records = engine.skip(now: at(minutes(5)))

        #expect(records.first?.activeSeconds == 180)
        #expect(engine.state.phase == .shortBreak)
        #expect(engine.state.status == .ready)
    }

    @Test func skippingVisitsPhasesInCycleOrder() {
        var engine = TimerEngine(preset: testPreset)
        var visited: [String] = []
        for _ in 0..<8 {
            visited.append("\(engine.state.phase.rawValue)\(engine.state.round)")
            engine.skip(now: at(0))
        }
        #expect(visited == [
            "work1", "shortBreak1", "work2", "longBreak2",
            "work1", "shortBreak1", "work2", "longBreak2",
        ])
    }

    @Test func restartResetsDurationAndRecordsPartial() {
        var engine = TimerEngine(preset: testPreset)
        engine.start(now: at(0))
        engine.adjust(by: minutes(5), now: at(0))
        let records = engine.restartPhase(now: at(minutes(3)))

        #expect(records.outcomes == [.restarted])
        #expect(engine.state.status == .running)
        #expect(engine.state.remaining(at: at(minutes(3))) == minutes(10))
    }

    @Test func restartWhilePausedReturnsToReady() {
        var engine = TimerEngine(preset: testPreset)
        engine.start(now: at(0))
        engine.pause(now: at(minutes(4)))
        let records = engine.restartPhase(now: at(minutes(6)))

        #expect(records.first?.activeSeconds == 240)
        #expect(engine.state.status == .ready)
        #expect(engine.state.phaseStartedAt == nil)
        #expect(engine.state.remaining(at: at(minutes(6))) == minutes(10))
    }

    @Test func restartKeepsPhaseAndRound() {
        var engine = TimerEngine(preset: testPreset)
        engine.start(now: at(0))
        engine.tick(now: at(minutes(11)))
        engine.restartPhase(now: at(minutes(11.5)))

        #expect(engine.state.phase == .shortBreak)
        #expect(engine.state.round == 1)
        #expect(engine.state.remaining(at: at(minutes(11.5))) == minutes(2))
    }

    @Test func stopReturnsToFreshCycle() {
        var engine = TimerEngine(preset: testPreset)
        engine.start(now: at(0))
        engine.skip(now: at(minutes(1)))
        let records = engine.stop(now: at(minutes(2)))

        #expect(records.phases == [.shortBreak])
        #expect(records.outcomes == [.stopped])
        #expect(engine.state == .fresh(testPreset))
    }

    @Test func stopDropsRoundAdjustments() {
        var engine = TimerEngine(preset: testPreset)
        engine.adjustRounds(by: 2)
        engine.start(now: at(0))
        engine.stop(now: at(minutes(1)))
        #expect(engine.state.totalRounds == testPreset.roundsBeforeLongBreak)
    }
}

@Suite struct AdjustTests {
    @Test func adjustExtendsAndShortensButKeepsMinimumRemaining() {
        var engine = TimerEngine(preset: testPreset)
        engine.start(now: at(0))
        engine.adjust(by: minutes(5), now: at(0))
        #expect(engine.state.remaining(at: at(0)) == minutes(15))

        engine.adjust(by: -minutes(20), now: at(minutes(5)))
        #expect(engine.state.remaining(at: at(minutes(5))) == TimerEngine.minimumRemaining)
    }

    @Test func shorteningBelowFloorNeverLengthens() {
        var engine = TimerEngine(preset: testPreset)
        engine.start(now: at(0))
        engine.adjust(by: -minutes(1), now: at(minutes(9.5)))  // 30s left
        #expect(engine.state.remaining(at: at(minutes(9.5))) == 30)
    }

    @Test func adjustWhilePausedUsesActiveTimeNotWallTime() {
        var engine = TimerEngine(preset: testPreset)
        engine.start(now: at(0))
        engine.pause(now: at(minutes(8)))
        engine.adjust(by: -minutes(5), now: at(minutes(30)))
        #expect(engine.state.remaining(at: at(minutes(30))) == TimerEngine.minimumRemaining)
    }

    @Test func adjustWhileReadyChangesUpcomingPhase() {
        var engine = TimerEngine(preset: testPreset)
        engine.adjust(by: minutes(5), now: at(0))
        engine.start(now: at(0))
        // `start` begins a fresh cycle, so the adjustment is dropped…
        #expect(engine.state.remaining(at: at(0)) == minutes(10))

        engine.stop(now: at(0))
        engine.adjust(by: minutes(5), now: at(0))
        engine.resume(now: at(0))
        // …while `resume` starts the prepared phase as adjusted.
        let records = engine.tick(now: at(minutes(15)))
        #expect(records.first?.plannedSeconds == 900)
    }

    @Test func adjustmentsDoNotCarryIntoNextPhase() {
        var engine = TimerEngine(preset: testPreset)
        engine.start(now: at(0))
        engine.adjust(by: minutes(5), now: at(0))
        engine.tick(now: at(minutes(15)))
        #expect(engine.state.phase == .shortBreak)
        #expect(engine.state.phaseDuration == minutes(2))
    }

    @Test func adjustRoundsIsClampedToCurrentRound() {
        var engine = TimerEngine(preset: testPreset)
        engine.adjustRounds(by: 3)
        #expect(engine.state.totalRounds == 5)
        engine.adjustRounds(by: -10)
        #expect(engine.state.totalRounds == 1)

        // On a short break after round 1, at least one more round must remain.
        engine.adjustRounds(by: 1)
        engine.start(now: at(0))
        engine.adjustRounds(by: 1)
        engine.tick(now: at(minutes(10)))
        engine.adjustRounds(by: -10)
        #expect(engine.state.phase == .shortBreak)
        #expect(engine.state.totalRounds == 2)
    }

    @Test func adjustRoundsHasUpperBound() {
        var engine = TimerEngine(preset: testPreset)
        engine.adjustRounds(by: 100)
        #expect(engine.state.totalRounds == TimerEngine.maximumRounds)
    }

    @Test func addingRoundsDelaysLongBreak() {
        var engine = TimerEngine(preset: testPreset)
        engine.start(now: at(0))
        engine.adjustRounds(by: 1)  // 3 rounds now
        engine.tick(now: at(minutes(12)))
        engine.resume(now: at(minutes(12)))
        engine.tick(now: at(minutes(22)))
        #expect(engine.state.phase == .shortBreak)
        #expect(engine.state.roundsLeft == 1)
    }

    @Test func removingRoundsBringsLongBreakForward() {
        var engine = TimerEngine(preset: testPreset)
        engine.start(now: at(0))
        engine.adjustRounds(by: -1)
        engine.tick(now: at(minutes(10)))
        #expect(engine.state.phase == .longBreak)
    }

    @Test func roundsAdjustedDuringLongBreakCarryIntoNextSet() {
        var engine = TimerEngine(preset: testPreset)
        engine.adjustRounds(by: 1)  // this set: 3 rounds
        for _ in 0..<5 { engine.skip(now: at(0)) }  // work1 short work2 short work3 → long
        #expect(engine.state.phase == .longBreak)
        #expect(engine.state.totalRounds == testPreset.roundsBeforeLongBreak)

        engine.adjustRounds(by: 2)
        engine.skip(now: at(0))
        #expect(engine.state.phase == .work)
        #expect(engine.state.round == 1)
        #expect(engine.state.totalRounds == 4)
    }
}

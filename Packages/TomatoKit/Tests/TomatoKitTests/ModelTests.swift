import Foundation
import Testing
@testable import TomatoKit

@Suite struct ModelTests {
    @Test func presetNeedsAtLeastOneRound() {
        let preset = Preset(name: "Zero", workMinutes: 25, shortBreakMinutes: 5, longBreakMinutes: 15,
                            roundsBeforeLongBreak: 0)
        #expect(preset.roundsBeforeLongBreak == 1)
    }

    @Test func presetDurationsAndAutoStart() {
        #expect(Preset.classic.duration(for: .work) == 1500)
        #expect(Preset.classic.duration(for: .shortBreak) == 300)
        #expect(Preset.classic.duration(for: .longBreak) == 900)

        #expect(testPreset.autoStarts(.shortBreak))
        #expect(testPreset.autoStarts(.longBreak))
        #expect(!testPreset.autoStarts(.work))
    }

    @Test func builtInPresetIDsAreStableAndUnique() {
        #expect(Set(Preset.builtIn.map(\.id)).count == Preset.builtIn.count)
        #expect(Preset.classic.id.uuidString == "00000000-0000-0000-0000-000000000001")
    }

    @Test func builtInIsDecidedByIDNotValues() {
        var edited = Preset.deep
        edited.name = "Renamed"
        edited.workMinutes = 5
        #expect(edited.isBuiltIn)

        var library = PresetLibrary.standard
        #expect(!library.add().isBuiltIn)  // a copy of Classic is a custom preset
        #expect(!testPreset.isBuiltIn)
    }

    @Test func onlyWorkIsNotRest() {
        #expect(Phase.allCases.filter { !$0.isRest } == [.work])
    }

    @Test func timerStateSurvivesJSONRoundTrip() throws {
        var engine = TimerEngine(preset: .deep)
        engine.start(now: at(0))
        engine.adjust(by: minutes(3), now: at(minutes(1)))
        engine.pause(now: at(minutes(7)))

        let data = try JSONEncoder().encode(engine.state)
        #expect(try JSONDecoder().decode(TimerState.self, from: data) == engine.state)
    }

    @Test(arguments: [nil, "client-work"])
    func sessionRecordSurvivesJSONRoundTrip(tag: String?) throws {
        let record = SessionRecord(phase: .longBreak, startedAt: at(0), endedAt: at(900), plannedSeconds: 900,
                                   activeSeconds: 870, outcome: .skipped, presetName: "Classic", tag: tag)
        let data = try JSONEncoder().encode(record)
        #expect(try JSONDecoder().decode(SessionRecord.self, from: data) == record)
    }

    @Test func recordEndingAtReflectsAdjustmentsAndThreshold() {
        var engine = TimerEngine(preset: testPreset)
        #expect(engine.state.record(endingAt: at(60), outcome: .stopped) == nil)  // not started

        engine.start(now: at(0))
        #expect(engine.state.record(endingAt: at(0.4), outcome: .stopped) == nil)  // under a second

        engine.adjust(by: minutes(2), now: at(0))
        let record = engine.state.record(endingAt: at(90), outcome: .stopped)
        #expect(record?.plannedSeconds == 720)
        #expect(record?.activeSeconds == 90)
        #expect(record?.presetName == "Test")
    }
}

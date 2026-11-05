import Foundation
import GRDB
import Testing
@testable import TomatoKit

@Suite struct HistoryStoreTests {
    private func record(
        _ phase: Phase = .work, from start: TimeInterval, to end: TimeInterval,
        outcome: SessionRecord.Outcome = .completed, tag: String? = nil
    ) -> SessionRecord {
        SessionRecord(phase: phase, startedAt: at(start), endedAt: at(end), plannedSeconds: Int(end - start),
                      activeSeconds: Int(end - start), outcome: outcome, presetName: "Test", tag: tag)
    }

    private func temporaryDatabaseURL() -> URL {
        FileManager.default.temporaryDirectory
            .appending(path: "TomatoKitTests-\(UUID().uuidString)/history.sqlite")
    }

    @Test(arguments: [nil, "client-work"])
    func recordsRoundTripWithAllFields(tag: String?) throws {
        let store = try HistoryStore.inMemory()
        let original = record(.longBreak, from: 0, to: 900, outcome: .skipped, tag: tag)
        try store.insert([original])
        #expect(try store.records(in: DateInterval(start: at(-60), end: at(1000))) == [original])
    }

    @Test func realDatesKeepMillisecondPrecision() throws {
        let store = try HistoryStore.inMemory()
        let now = Date.now
        try store.insert([SessionRecord(phase: .work, startedAt: now.addingTimeInterval(-90), endedAt: now,
                                        plannedSeconds: 90, activeSeconds: 90, outcome: .stopped, presetName: "T")])
        let stored = try #require(try store.records(in: DateInterval(start: now.addingTimeInterval(-100), end: now.addingTimeInterval(1))).first)
        #expect(abs(stored.endedAt.timeIntervalSince(now)) < 0.001)
    }

    @Test func intervalQueryIncludesStraddlingAndExcludesAdjacentSessions() throws {
        let store = try HistoryStore.inMemory()
        let interval = DateInterval(start: at(1000), end: at(2000))
        let endsAtStart = record(from: 500, to: 1000)
        let straddlesStart = record(from: 900, to: 1100)
        let inside = record(from: 1200, to: 1300)
        let straddlesEnd = record(from: 1900, to: 2100)
        let startsAtEnd = record(from: 2000, to: 2100)
        try store.insert([startsAtEnd, inside, endsAtStart, straddlesEnd, straddlesStart])

        #expect(try store.records(in: interval) == [straddlesStart, inside, straddlesEnd])
    }

    @Test func totalsMatchInMemoryCalculation() throws {
        let store = try HistoryStore.inMemory()
        let records = [
            record(.work, from: 0, to: 1500),
            record(.shortBreak, from: 1500, to: 1800),
            record(.work, from: 1800, to: 2400, outcome: .stopped),
        ]
        try store.insert(records)
        let day = DateInterval(start: at(-3600), duration: 86_400)

        let totals = try store.totals(in: day)
        #expect(totals == Totals(records, in: day))
        #expect(totals.worked == 2100)
        #expect(totals.rested == 300)
        #expect(totals.pomodoros == 1)
    }

    @Test func noSavedStateLoadsAsNil() throws {
        #expect(try HistoryStore.inMemory().loadTimerState() == nil)
    }

    @Test func savesStateWithRecordsAndKeepsLatestState() throws {
        let store = try HistoryStore.inMemory()
        var engine = TimerEngine(preset: testPreset)
        engine.start(now: at(0))
        try store.save(state: engine.state)

        let finished = engine.skip(now: at(120))
        try store.save(state: engine.state, adding: finished)

        #expect(try store.loadTimerState() == engine.state)
        #expect(try store.records(in: DateInterval(start: at(0), end: at(200))) == finished)
    }

    @Test func failedSaveChangesNothing() throws {
        let store = try HistoryStore.inMemory()
        var engine = TimerEngine(preset: testPreset)
        engine.start(now: at(0))
        let finished = engine.skip(now: at(120))
        try store.save(state: engine.state, adding: finished)
        let savedState = engine.state

        // Re-inserting the same record violates the primary key, so the
        // whole transaction (including the new state) must roll back.
        engine.pause(now: at(180))
        #expect(throws: (any Error).self) { try store.save(state: engine.state, adding: finished) }
        #expect(try store.loadTimerState() == savedState)
        #expect(try store.records(in: DateInterval(start: at(0), end: at(200))).count == 1)
    }

    @Test func storesReadableColumnValues() throws {
        let url = temporaryDatabaseURL()
        let original = record(.shortBreak, from: 0, to: 300, outcome: .skipped)
        try HistoryStore.open(at: url).insert([original])

        let row = try DatabaseQueue(path: url.path).read { db in
            try Row.fetchOne(db, sql: "SELECT id, typeof(id) AS idType, phase, outcome, startedAt FROM session")
        }
        #expect(row?["idType"] == "text")
        #expect(row?["id"] == original.id.uuidString)
        #expect(row?["phase"] == "shortBreak")
        #expect(row?["outcome"] == "skipped")
        #expect((row?["startedAt"] as String?)?.hasPrefix("2027-01-15") == true)
    }

    @Test func reopeningFileKeepsData() throws {
        let url = temporaryDatabaseURL()
        let original = record(from: 0, to: 600)
        try HistoryStore.open(at: url).insert([original])

        let reopened = try HistoryStore.open(at: url)
        #expect(try reopened.records(in: DateInterval(start: at(0), end: at(600))) == [original])
    }
}

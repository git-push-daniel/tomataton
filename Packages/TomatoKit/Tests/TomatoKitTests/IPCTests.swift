import Foundation
import Synchronization
import Testing
@testable import TomatoKit

@Suite struct DurationParserTests {
    @Test(arguments: [
        ("5m", 300), ("5", 300), ("90", 5400), ("-2m", -120), ("+30s", 30),
        ("1h", 3600), ("1h30m", 5400), ("1.5h", 5400), ("25min", 1500),
        ("2 minutes", nil), ("10 m", nil),  // no spaces inside
        (" 45s ", 45), ("1H", 3600),
    ] as [(String, Int?)])
    func parses(text: String, expected: Int?) {
        #expect(DurationParser.seconds(from: text) == expected)
    }

    @Test(arguments: ["", "-", "m", "5x", "abc", "1h-5m", "..m"])
    func rejectsGarbage(text: String) {
        #expect(DurationParser.seconds(from: text) == nil)
    }
}

@Suite struct PresetOverridesTests {
    @Test func emptyOverridesKeepPresetAsIs() {
        #expect(PresetOverrides().applied(to: .classic) == .classic)
    }

    @Test func overridesMakeASanitizedOneOffCopy() {
        let custom = PresetOverrides(workMinutes: 50, rounds: 99).applied(to: .classic)
        #expect(custom.id != Preset.classic.id)
        #expect(custom.name == "Classic (custom)")
        #expect(custom.workMinutes == 50)
        #expect(custom.shortBreakMinutes == Preset.classic.shortBreakMinutes)
        #expect(custom.roundsBeforeLongBreak == TimerEngine.maximumRounds)
        #expect(!custom.isBuiltIn)
        #expect(PresetOverrides(workMinutes: 45).applied(to: custom).name == "Classic (custom)")
    }
}

@Suite struct CLITextTests {
    private let text: CLIText = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        calendar.firstWeekday = 2
        return CLIText(locale: Locale(identifier: "en_GB"), calendar: calendar)
    }()

    private func snapshot(_ change: (inout TimerEngine) -> Void = { _ in }) -> StatusSnapshot {
        var engine = TimerEngine(preset: testPreset)
        change(&engine)
        var totals = Totals()
        totals.worked = 8100
        totals.rested = 2100
        totals.pomodoros = 6
        return StatusSnapshot(state: engine.state, now: at(minutes(2)), today: totals,
                              day: DateInterval(start: t0, duration: 86_400))
    }

    @Test func shortLineIsEmptyUntilStartedThenShowsPhaseAndClock() {
        #expect(text.short(snapshot()) == "")
        #expect(text.short(snapshot { $0.start(now: at(0)) }) == "🍅 8:00")
        #expect(text.short(snapshot { $0.start(now: at(0)); $0.pause(now: at(30)) }) == "⏸ 9:30")
        #expect(text.short(snapshot { $0.start(now: at(0)); $0.skip(now: at(60)) }) == "☕ 1:00")
    }

    @Test func statusDescribesPhaseRoundAndToday() {
        #expect(text.status(snapshot { $0.start(now: at(0)) }) == """
        Focus · 8:00 left
        Round 1 of 2 · Test
        Today: 2h 15m focus · 35m rest · 6 🍅
        """)
        #expect(text.status(snapshot()).hasPrefix("Focus · 10:00 · ready to start"))
        #expect(text.status(snapshot { $0.start(now: at(0)); $0.pause(now: at(0)) }).hasPrefix("Focus · 10:00 left · paused"))
    }

    @Test func presetsAreAlignedAndMarked() {
        var library = PresetLibrary.standard
        library.setDefault(id: Preset.deep.id)
        let list = PresetList(presets: library.presets, defaultID: library.defaultID, inUseID: Preset.quick.id)
        #expect(text.presets(list) == """
          Classic  25/5/15 min ×4
          Deep     50/10/30 min ×2  (default)
        ▸ Quick    15/3/10 min ×4  (in use)
        """)
    }

    @Test func weekStatsDrawScaledBarsWithTotals() {
        let week = text.calendar.week(containing: at(0))!
        var records: [SessionRecord] = []
        let monday = week.start.addingTimeInterval(9 * 3600)
        records.append(SessionRecord(phase: .work, startedAt: monday, endedAt: monday + 3600 * 3, plannedSeconds: 10800,
                                     activeSeconds: 10800, outcome: .completed, presetName: "T"))
        records.append(SessionRecord(phase: .shortBreak, startedAt: monday + 3600 * 3, endedAt: monday + 3600 * 4,
                                     plannedSeconds: 3600, activeSeconds: 3600, outcome: .completed, presetName: "T"))
        let wednesday = monday + 2 * 86_400
        records.append(SessionRecord(phase: .work, startedAt: wednesday, endedAt: wednesday + 1800, plannedSeconds: 1800,
                                     activeSeconds: 1800, outcome: .stopped, presetName: "T"))
        let report = StatsReport(range: .week, interval: week,
                                 days: Totals.daily(records, in: week, calendar: text.calendar))
        let lines = text.stats(report).components(separatedBy: "\n")

        #expect(lines[0] == "Week of 11 Jan – 17 Jan 2027")
        #expect(lines[1] == "█ focus  ▒ rest")
        #expect(lines[3] == "Mon 11  ███████████████▒▒▒▒▒  3h focus · 1h rest · 1 🍅")
        #expect(lines[4] == "Tue 12  –")
        #expect(lines[5] == "Wed 13  ███                   30m focus · 0m rest · 0 🍅")
        #expect(lines.last == "Total: 3h 30m focus · 1h rest · 1 🍅")
    }

    @Test func colorOnlyChangesTheBars() {
        var colored = text
        colored.color = true
        let report = StatsReport(range: .today, interval: DateInterval(start: t0, duration: 86_400),
                                 days: [DayTotals(day: DateInterval(start: t0, duration: 86_400), totals: Totals())])
        #expect(colored.stats(report) == text.stats(report))
        #expect(text.stats(report) == "Today (Fri 15 Jan): 0m focus · 0m rest · 0 🍅")
    }
}

/// Serialized, and clients run on GCD threads: a blocking client on Swift
/// concurrency's cooperative pool could starve the in-process server.
@Suite(.serialized) struct CommandChannelTests {
    /// Short path: socket paths are limited to 104 bytes.
    private func socketPath() -> String {
        NSTemporaryDirectory() + "tk-\(UUID().uuidString.prefix(8)).sock"
    }

    @Test func requestAndResponseRoundTrip() throws {
        let path = socketPath()
        let server = try CommandChannel.serve(at: path) { request in
            switch request {
            case .adjust(let seconds): .failure("adjust \(seconds)")
            case .deletePreset(let name): .failure("delete \(name)")
            default: .failure("other")
            }
        }
        defer { server.stop() }

        #expect(try CommandChannel.send(.adjust(seconds: -120), to: path) == .failure("adjust -120"))
        #expect(try CommandChannel.send(.deletePreset(name: "Deep ✨"), to: path) == .failure("delete Deep ✨"))
        #expect(try CommandChannel.send(.status, to: path) == .failure("other"))
    }

    @Test func handlesConcurrentClients() throws {
        let path = socketPath()
        let server = try CommandChannel.serve(at: path) { request in
            if case .adjust(let seconds) = request { return .failure("\(seconds)") }
            return .failure("?")
        }
        defer { server.stop() }

        let replies = Mutex<[String]>([])
        DispatchQueue.concurrentPerform(iterations: 20) { index in
            let reply = (try? CommandChannel.send(.adjust(seconds: index), to: path)).map { "\($0)" } ?? "error"
            replies.withLock { $0.append(reply) }
        }
        let all = replies.withLock { $0 }
        #expect(!all.contains("error"))
        #expect(Set(all).count == 20)
    }

    @Test func socketIsPrivateAndRemovedOnStop() throws {
        let path = socketPath()
        let server = try CommandChannel.serve(at: path) { _ in .failure("") }
        let permissions = try FileManager.default.attributesOfItem(atPath: path)[.posixPermissions] as? Int
        #expect(permissions == 0o600)

        server.stop()
        Thread.sleep(forTimeInterval: 0.1)  // cancellation runs on the socket queue
        #expect(!FileManager.default.fileExists(atPath: path))
    }

    @Test func missingServerIsReportedAsNotRunning() {
        #expect(throws: UnixSocketError.notRunning) {
            try CommandChannel.send(.status, to: socketPath())
        }
    }

    @Test func staleSocketFileIsNotRunningAndCanBeReplaced() throws {
        let path = socketPath()
        let first = try CommandChannel.serve(at: path) { _ in .failure("first") }
        // Simulate a crash: the file stays but nobody listens. Cancelling would
        // unlink it, so keep the file by creating it again by hand afterwards.
        first.stop()
        Thread.sleep(forTimeInterval: 0.1)
        FileManager.default.createFile(atPath: path, contents: nil)
        #expect(throws: (any Error).self) { try CommandChannel.send(.status, to: path) }

        let second = try CommandChannel.serve(at: path) { _ in .failure("second") }
        defer { second.stop() }
        #expect(try CommandChannel.send(.status, to: path) == .failure("second"))
    }

    @Test func garbageGetsAFailureReply() throws {
        let path = socketPath()
        let server = try CommandChannel.serve(at: path) { _ in .status(StatusSnapshot(
            state: .fresh(.classic), now: t0, today: Totals(), day: DateInterval(start: t0, duration: 1)
        )) }
        defer { server.stop() }

        let reply = try UnixSocketClient.send(Data("{\"launchMissiles\":{}}".utf8), to: path)
        let response = try IPCCoding.decoder().decode(IPCResponse.self, from: reply)
        guard case .failure(let message) = response else {
            Issue.record("Expected a failure, got \(response)")
            return
        }
        #expect(message.contains("different versions"))
    }

    @Test func socketPathIsStableShortAndPerSupportFolder() {
        #expect(AppPaths.stableHash("/a") == AppPaths.stableHash("/a"))
        #expect(AppPaths.stableHash("/a") != AppPaths.stableHash("/b"))
        #expect(AppPaths.socket.path.utf8.count < 104)
    }
}

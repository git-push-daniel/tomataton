import Foundation
@testable import TomatoKit

let t0 = Date(timeIntervalSince1970: 1_800_000_000)
func at(_ seconds: TimeInterval) -> Date { t0.addingTimeInterval(seconds) }
func minutes(_ m: Double) -> TimeInterval { m * 60 }

/// 10/2/5 × 2 rounds; breaks auto-start, work waits for the user.
let testPreset = Preset(
    name: "Test", workMinutes: 10, shortBreakMinutes: 2, longBreakMinutes: 5,
    roundsBeforeLongBreak: 2, autoStartBreaks: true, autoStartWork: false
)

/// Same lengths, but every phase auto-starts.
let nonstopPreset = Preset(
    name: "Nonstop", workMinutes: 10, shortBreakMinutes: 2, longBreakMinutes: 5,
    roundsBeforeLongBreak: 2, autoStartBreaks: true, autoStartWork: true
)

/// Same lengths, nothing auto-starts.
let manualPreset = Preset(
    name: "Manual", workMinutes: 10, shortBreakMinutes: 2, longBreakMinutes: 5,
    roundsBeforeLongBreak: 2, autoStartBreaks: false, autoStartWork: false
)

extension Array where Element == SessionRecord {
    var phases: [Phase] { map(\.phase) }
    var outcomes: [SessionRecord.Outcome] { map(\.outcome) }

    /// Records with ids blanked, for comparing runs that generate fresh UUIDs.
    var withoutIDs: [SessionRecord] {
        map { var copy = $0; copy.id = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!; return copy }
    }
}

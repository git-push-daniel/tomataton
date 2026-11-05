import Foundation

/// Snapshot of the live timer. Purely date-based: nothing here counts ticks,
/// so the state stays correct across sleep, app restarts and slow run loops.
public struct TimerState: Codable, Sendable, Equatable {
    public enum Status: String, Codable, Sendable {
        /// Phase is prepared but hasn't started counting yet.
        case ready
        case running
        case paused
    }

    public var status: Status
    public var phase: Phase
    /// 1-based index of the current (or just finished) work round in this set.
    public var round: Int
    /// Work rounds in this set before the long break. Adjustable on the fly.
    public var totalRounds: Int
    public var preset: Preset
    /// Planned length of the current phase, including any ± adjustments.
    public var phaseDuration: TimeInterval
    /// When the phase first started running; nil while `ready`.
    public var phaseStartedAt: Date?
    /// Start of the current running stretch; nil unless `running`.
    public var runningSince: Date?
    /// Active time accumulated before `runningSince` (i.e. before the last pause).
    public var activeBefore: TimeInterval

    public static func fresh(_ preset: Preset) -> TimerState {
        TimerState(
            status: .ready,
            phase: .work,
            round: 1,
            totalRounds: preset.roundsBeforeLongBreak,
            preset: preset,
            phaseDuration: preset.duration(for: .work),
            phaseStartedAt: nil,
            runningSince: nil,
            activeBefore: 0
        )
    }

    public func activeElapsed(at now: Date) -> TimeInterval {
        guard let runningSince else { return activeBefore }
        return activeBefore + max(0, now.timeIntervalSince(runningSince))
    }

    public func remaining(at now: Date) -> TimeInterval {
        max(0, phaseDuration - activeElapsed(at: now))
    }

    /// When the current phase will end; only known while running.
    public var endsAt: Date? {
        runningSince.map { $0.addingTimeInterval(phaseDuration - activeBefore) }
    }

    /// Work rounds still to start before the long break.
    public var roundsLeft: Int { max(0, totalRounds - round) }

    /// History record for the current phase as if it ended at `date`, or nil
    /// if nothing has been spent on it yet.
    public func record(endingAt date: Date, outcome: SessionRecord.Outcome) -> SessionRecord? {
        guard let phaseStartedAt else { return nil }
        let active = Int(activeElapsed(at: date).rounded())
        guard active >= TimerEngine.minimumRecordedSeconds else { return nil }
        return SessionRecord(
            phase: phase,
            startedAt: phaseStartedAt,
            endedAt: date,
            plannedSeconds: Int(phaseDuration.rounded()),
            activeSeconds: active,
            outcome: outcome,
            presetName: preset.name
        )
    }
}

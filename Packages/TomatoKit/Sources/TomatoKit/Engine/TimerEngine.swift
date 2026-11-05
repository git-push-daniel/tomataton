import Foundation

/// Pure Pomodoro state machine. Every operation takes `now` explicitly so the
/// engine has no hidden clock and is fully deterministic under test.
///
/// Mutations that end a phase return the resulting `SessionRecord`s; the
/// caller is responsible for persisting them.
public struct TimerEngine: Sendable {
    /// Shortening a phase never leaves less than this much time on the clock.
    public static let minimumRemaining: TimeInterval = 60
    public static let maximumRounds = 12
    /// Partial phases shorter than this aren't worth recording.
    static let minimumRecordedSeconds = 1

    public private(set) var state: TimerState

    public init(preset: Preset) {
        state = .fresh(preset)
    }

    public init(state: TimerState) {
        self.state = state
    }

    // MARK: - Lifecycle

    /// Abandons whatever is in progress and starts a fresh cycle, running.
    @discardableResult
    public mutating func start(preset: Preset? = nil, now: Date) -> [SessionRecord] {
        let records = record(.stopped, now: now)
        state = .fresh(preset ?? state.preset)
        begin(at: now)
        return records
    }

    /// Abandons whatever is in progress and prepares a fresh cycle without starting it.
    @discardableResult
    public mutating func select(preset: Preset, now: Date) -> [SessionRecord] {
        let records = record(.stopped, now: now)
        state = .fresh(preset)
        return records
    }

    /// Starts a `ready` phase or continues a `paused` one.
    public mutating func resume(now: Date) {
        guard state.status != .running else { return }
        begin(at: now)
    }

    public mutating func pause(now: Date) {
        guard state.status == .running else { return }
        state.activeBefore = state.activeElapsed(at: now)
        state.runningSince = nil
        state.status = .paused
    }

    public mutating func toggle(now: Date) {
        if state.status == .running {
            pause(now: now)
        } else {
            resume(now: now)
        }
    }

    /// Ends the cycle and returns to a fresh, ready work phase.
    @discardableResult
    public mutating func stop(now: Date) -> [SessionRecord] {
        let records = record(.stopped, now: now)
        state = .fresh(state.preset)
        return records
    }

    /// Jumps to the next phase. Keeps running if the timer was running.
    @discardableResult
    public mutating func skip(now: Date) -> [SessionRecord] {
        let records = record(.skipped, now: now)
        let wasRunning = state.status == .running
        advance(startingAt: wasRunning ? now : nil)
        return records
    }

    /// Restarts the current phase from its full preset length.
    @discardableResult
    public mutating func restartPhase(now: Date) -> [SessionRecord] {
        let records = record(.restarted, now: now)
        let wasRunning = state.status == .running
        prepare(phase: state.phase)
        if wasRunning { begin(at: now) }
        return records
    }

    /// Completes any phases whose end time has passed. Call this periodically
    /// (e.g. every second from the UI) and on wake.
    ///
    /// If auto-start is on, several phases may complete in one call, each
    /// starting exactly when the previous one ended.
    @discardableResult
    public mutating func tick(now: Date) -> [SessionRecord] {
        var records: [SessionRecord] = []
        // Bounded so a misconfigured preset can never spin forever.
        for _ in 0..<1000 {
            guard state.status == .running, let endsAt = state.endsAt, endsAt <= now else { break }
            records += record(.completed, now: endsAt)
            let next = nextPhase()
            advance(startingAt: state.preset.autoStarts(next.phase) ? endsAt : nil)
        }
        return records
    }

    // MARK: - Quick adjust

    /// Lengthens (positive) or shortens (negative) the current phase.
    public mutating func adjust(by delta: TimeInterval, now: Date) {
        let floor = state.activeElapsed(at: now) + Self.minimumRemaining
        let proposed = state.phaseDuration + delta
        // Never shorten below the floor, but don't let the floor lengthen a phase either.
        state.phaseDuration = max(proposed, min(state.phaseDuration, floor))
    }

    /// Adds or removes work rounds before the long break.
    public mutating func adjustRounds(by delta: Int) {
        let lowerBound = switch state.phase {
        case .work: state.round
        case .shortBreak: state.round + 1
        case .longBreak: 1
        }
        state.totalRounds = min(max(state.totalRounds + delta, lowerBound), Self.maximumRounds)
    }

    // MARK: - Preset edits

    /// Applies edits to the preset in use. A phase that has already started
    /// keeps its length; everything after it uses the new values. Round
    /// adjustments are replaced by the preset's round count.
    public mutating func updatePreset(_ preset: Preset) {
        state.preset = preset
        if state.phaseStartedAt == nil {
            state.phaseDuration = preset.duration(for: state.phase)
        }
        state.totalRounds = preset.roundsBeforeLongBreak
        adjustRounds(by: 0)  // clamp so the current round still fits
    }

    // MARK: - Internals

    private mutating func begin(at date: Date) {
        state.status = .running
        state.runningSince = date
        if state.phaseStartedAt == nil { state.phaseStartedAt = date }
    }

    private mutating func prepare(phase: Phase) {
        state.phase = phase
        state.phaseDuration = state.preset.duration(for: phase)
        state.status = .ready
        state.phaseStartedAt = nil
        state.runningSince = nil
        state.activeBefore = 0
    }

    private func nextPhase() -> (phase: Phase, round: Int) {
        switch state.phase {
        case .work:
            (state.round >= state.totalRounds ? .longBreak : .shortBreak, state.round)
        case .shortBreak:
            (.work, state.round + 1)
        case .longBreak:
            (.work, 1)
        }
    }

    private mutating func advance(startingAt date: Date?) {
        let next = nextPhase()
        if next.phase == .longBreak {
            // Rounds adjusted during the long break carry into the next set.
            state.totalRounds = state.preset.roundsBeforeLongBreak
        }
        state.round = next.round
        prepare(phase: next.phase)
        if let date { begin(at: date) }
    }

    private func record(_ outcome: SessionRecord.Outcome, now: Date) -> [SessionRecord] {
        state.record(endingAt: now, outcome: outcome).map { [$0] } ?? []
    }
}

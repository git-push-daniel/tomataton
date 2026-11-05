import Foundation

/// What the CLI can ask the app to do. Sent as one JSON line over the socket.
public enum IPCRequest: Codable, Sendable, Equatable {
    case status
    /// Starts a fresh cycle. `preset` is a name (case-insensitive); nil means
    /// the preset in use. Any `overrides` apply to this run only.
    case start(preset: String?, overrides: PresetOverrides?)
    case resume
    case pause
    case toggle
    case stop
    case skip
    case restart
    case adjust(seconds: Int)
    case adjustRounds(delta: Int)
    case listPresets
    case addPreset(Preset)
    case deletePreset(name: String)
    case stats(StatsRange)
}

public enum IPCResponse: Codable, Sendable, Equatable {
    case status(StatusSnapshot)
    case presets(PresetList)
    case stats(StatsReport)
    case failure(String)
}

public enum StatsRange: String, Codable, Sendable, CaseIterable {
    case today
    case week
}

/// Per-run changes to a preset, e.g. `tomataton start --work 50`.
public struct PresetOverrides: Codable, Sendable, Equatable {
    public var workMinutes: Int?
    public var shortBreakMinutes: Int?
    public var longBreakMinutes: Int?
    public var rounds: Int?

    public init(workMinutes: Int? = nil, shortBreakMinutes: Int? = nil, longBreakMinutes: Int? = nil, rounds: Int? = nil) {
        self.workMinutes = workMinutes
        self.shortBreakMinutes = shortBreakMinutes
        self.longBreakMinutes = longBreakMinutes
        self.rounds = rounds
    }

    public var isEmpty: Bool {
        workMinutes == nil && shortBreakMinutes == nil && longBreakMinutes == nil && rounds == nil
    }

    /// A one-off copy of `preset` with the overrides applied. It gets a new id,
    /// so it's never mistaken for (or saved over) the library preset.
    public func applied(to preset: Preset) -> Preset {
        guard !isEmpty else { return preset }
        var copy = preset
        copy.id = UUID()
        copy.name = preset.name.hasSuffix(" (custom)") ? preset.name : "\(preset.name) (custom)"
        if let workMinutes { copy.workMinutes = workMinutes }
        if let shortBreakMinutes { copy.shortBreakMinutes = shortBreakMinutes }
        if let longBreakMinutes { copy.longBreakMinutes = longBreakMinutes }
        if let rounds { copy.roundsBeforeLongBreak = rounds }
        return copy.sanitized()
    }
}

/// The timer as seen from outside the app.
public struct StatusSnapshot: Codable, Sendable, Equatable {
    public var status: TimerState.Status
    public var phase: Phase
    public var round: Int
    public var totalRounds: Int
    public var remainingSeconds: Int
    public var phaseSeconds: Int
    /// When the phase ends; only while running.
    public var endsAt: Date?
    public var presetName: String
    public var today: DaySummary

    public init(state: TimerState, now: Date, today: Totals, day: DateInterval) {
        status = state.status
        phase = state.phase
        round = state.round
        totalRounds = state.totalRounds
        remainingSeconds = Int(state.remaining(at: now).rounded(.up))
        phaseSeconds = Int(state.phaseDuration.rounded())
        endsAt = state.endsAt
        presetName = state.preset.name
        self.today = DaySummary(day: day.start, totals: today)
    }
}

public struct DaySummary: Codable, Sendable, Equatable {
    public var day: Date
    public var workedSeconds: Int
    public var restedSeconds: Int
    public var pomodoros: Int

    public init(day: Date, totals: Totals) {
        self.day = day
        workedSeconds = Int(totals.worked.rounded())
        restedSeconds = Int(totals.rested.rounded())
        pomodoros = totals.pomodoros
    }
}

public struct StatsReport: Codable, Sendable, Equatable {
    public var range: StatsRange
    public var start: Date
    public var end: Date
    public var days: [DaySummary]

    public init(range: StatsRange, interval: DateInterval, days: [DayTotals]) {
        self.range = range
        start = interval.start
        end = interval.end
        self.days = days.map { DaySummary(day: $0.day.start, totals: $0.totals) }
    }
}

public struct PresetList: Codable, Sendable, Equatable {
    public var presets: [Preset]
    public var defaultID: Preset.ID
    /// The preset the timer is using, if it's one from the list.
    public var inUseID: Preset.ID?

    public init(presets: [Preset], defaultID: Preset.ID, inUseID: Preset.ID?) {
        self.presets = presets
        self.defaultID = defaultID
        self.inUseID = inUseID
    }
}

/// JSON coding shared by both ends of the socket.
public enum IPCCoding {
    public static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    public static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

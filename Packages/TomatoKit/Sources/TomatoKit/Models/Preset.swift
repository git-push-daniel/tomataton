import Foundation

public struct Preset: Codable, Sendable, Hashable, Identifiable {
    public var id: UUID
    public var name: String
    public var workMinutes: Int
    public var shortBreakMinutes: Int
    public var longBreakMinutes: Int
    public var roundsBeforeLongBreak: Int
    public var autoStartBreaks: Bool
    public var autoStartWork: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        workMinutes: Int,
        shortBreakMinutes: Int,
        longBreakMinutes: Int,
        roundsBeforeLongBreak: Int,
        autoStartBreaks: Bool = true,
        autoStartWork: Bool = false
    ) {
        self.id = id
        self.name = name
        self.workMinutes = workMinutes
        self.shortBreakMinutes = shortBreakMinutes
        self.longBreakMinutes = longBreakMinutes
        self.roundsBeforeLongBreak = max(1, roundsBeforeLongBreak)
        self.autoStartBreaks = autoStartBreaks
        self.autoStartWork = autoStartWork
    }

    public func duration(for phase: Phase) -> TimeInterval {
        let minutes = switch phase {
        case .work: workMinutes
        case .shortBreak: shortBreakMinutes
        case .longBreak: longBreakMinutes
        }
        return TimeInterval(minutes * 60)
    }

    public func autoStarts(_ phase: Phase) -> Bool {
        phase.isRest ? autoStartBreaks : autoStartWork
    }

    // MARK: - Validation

    public static let workRange = 1...180
    public static let shortBreakRange = 1...60
    public static let longBreakRange = 1...120
    public static let roundsRange = 1...TimerEngine.maximumRounds
    public static let maximumNameLength = 30

    /// A copy with every value clamped to its allowed range and a usable name.
    public func sanitized() -> Preset {
        var copy = self
        copy.name = Self.cleanName(name)
        copy.workMinutes = workMinutes.clamped(to: Self.workRange)
        copy.shortBreakMinutes = shortBreakMinutes.clamped(to: Self.shortBreakRange)
        copy.longBreakMinutes = longBreakMinutes.clamped(to: Self.longBreakRange)
        copy.roundsBeforeLongBreak = roundsBeforeLongBreak.clamped(to: Self.roundsRange)
        return copy
    }

    static func cleanName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled" : String(trimmed.prefix(maximumNameLength))
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

extension Preset {
    // Fixed ids so built-ins stay stable across launches.
    public static let classic = Preset(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        name: "Classic", workMinutes: 25, shortBreakMinutes: 5, longBreakMinutes: 15, roundsBeforeLongBreak: 4
    )
    public static let deep = Preset(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        name: "Deep", workMinutes: 50, shortBreakMinutes: 10, longBreakMinutes: 30, roundsBeforeLongBreak: 2
    )
    public static let quick = Preset(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
        name: "Quick", workMinutes: 15, shortBreakMinutes: 3, longBreakMinutes: 10, roundsBeforeLongBreak: 4
    )

    public static let builtIn: [Preset] = [.classic, .deep, .quick]

    /// Whether this is one of the presets Tomataton ships with (even if edited).
    public var isBuiltIn: Bool {
        Self.builtIn.contains { $0.id == id }
    }
}

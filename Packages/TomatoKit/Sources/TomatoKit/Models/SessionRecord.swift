import Foundation

/// One finished (or cut-short) phase, as stored in history.
public struct SessionRecord: Codable, Sendable, Equatable, Identifiable {
    public enum Outcome: String, Codable, Sendable {
        case completed
        case skipped
        case stopped
        case restarted
    }

    public var id: UUID
    public var phase: Phase
    public var startedAt: Date
    public var endedAt: Date
    public var plannedSeconds: Int
    /// Time actually spent in the phase, pauses excluded.
    public var activeSeconds: Int
    public var outcome: Outcome
    public var presetName: String
    public var tag: String?

    public init(
        id: UUID = UUID(),
        phase: Phase,
        startedAt: Date,
        endedAt: Date,
        plannedSeconds: Int,
        activeSeconds: Int,
        outcome: Outcome,
        presetName: String,
        tag: String? = nil
    ) {
        self.id = id
        self.phase = phase
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.plannedSeconds = plannedSeconds
        self.activeSeconds = activeSeconds
        self.outcome = outcome
        self.presetName = presetName
        self.tag = tag
    }
}

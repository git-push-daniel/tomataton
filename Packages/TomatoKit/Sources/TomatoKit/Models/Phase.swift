public enum Phase: String, Codable, Sendable, CaseIterable {
    case work
    case shortBreak
    case longBreak

    public var isRest: Bool { self != .work }

    public var displayName: String {
        switch self {
        case .work: "Focus"
        case .shortBreak: "Short break"
        case .longBreak: "Long break"
        }
    }
}

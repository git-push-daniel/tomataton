import ArgumentParser
import Foundation
import TomatoKit

struct Status: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Show the timer and today's totals. Never launches the app."
    )

    @Flag(help: "One short token for shell prompts, e.g. \"🍅 18:42\". Prints nothing when idle or not running.")
    var short = false

    @Flag(help: "Print JSON.")
    var json = false

    func run() throws {
        let response: IPCResponse
        do {
            response = try Client.send(.status, launching: false)
        } catch {
            if short { return }  // keep prompts quiet
            throw error
        }
        guard case .status(let status) = response else { throw CLIError("Unexpected reply from the app.") }
        if json {
            try Output.json(status)
        } else if short {
            let token = Output.text.short(status)
            if !token.isEmpty { print(token) }
        } else {
            print(Output.text.status(status))
        }
    }
}

struct Start: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Start a fresh cycle, or resume.",
        discussion: """
        With no arguments, starts or resumes the current phase.
        With a preset name or any duration option, abandons the current phase and starts a new cycle.
        Duration options apply to this run only; they don't change the preset.

          tomataton start               # start / resume
          tomataton start deep          # fresh cycle with the Deep preset
          tomataton start --work 50     # current preset, but 50-minute focus sessions
        """
    )

    @Argument(help: "Preset name (see `tomataton presets`). Case-insensitive.")
    var preset: String?

    @Option(help: "Focus minutes.")
    var work: Int?

    @Option(name: .customLong("break"), help: "Short break minutes.")
    var shortBreak: Int?

    @Option(help: "Long break minutes.")
    var long: Int?

    @Option(help: "Focus sessions before each long break.")
    var rounds: Int?

    func run() throws {
        let overrides = PresetOverrides(workMinutes: work, shortBreakMinutes: shortBreak,
                                        longBreakMinutes: long, rounds: rounds)
        if preset == nil && overrides.isEmpty {
            try Client.run(.resume)
        } else {
            try Client.run(.start(preset: preset, overrides: overrides.isEmpty ? nil : overrides))
        }
    }
}

struct Pause: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Pause the timer.")
    func run() throws { try Client.run(.pause) }
}

struct Resume: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Start or resume the current phase.")
    func run() throws { try Client.run(.resume) }
}

struct Toggle: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Pause if running, otherwise start or resume.")
    func run() throws { try Client.run(.toggle) }
}

struct Stop: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Stop and reset the whole cycle.")
    func run() throws { try Client.run(.stop) }
}

struct Skip: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Skip to the next phase.")
    func run() throws { try Client.run(.skip) }
}

struct Restart: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Restart the current phase from the beginning.")
    func run() throws { try Client.run(.restart) }
}

struct Add: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Add time to the current phase, or remove it with a minus.",
        discussion: "Examples: 5m, -2m, 30s, 1h, 1h30m. A bare number means minutes."
    )

    // `.allUnrecognized` so "-2m" is taken as a value instead of an unknown option.
    @Argument(parsing: .allUnrecognized, help: "How much, e.g. 5m or -2m.")
    var amount: [String] = []

    // In validate(), not run(), so errors print this command's usage.
    func validate() throws {
        guard seconds != nil else { throw ValidationError("Give one amount, like 5m, -2m, 30s or 1h.") }
    }

    func run() throws {
        try Client.run(.adjust(seconds: seconds ?? 0))
    }

    private var seconds: Int? {
        guard amount.count == 1, let seconds = DurationParser.seconds(from: amount[0]), seconds != 0 else { return nil }
        return seconds
    }
}

struct Rounds: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Add or remove focus sessions before the long break: +1, -1."
    )

    @Argument(parsing: .allUnrecognized, help: "Change, e.g. +1 or -2.")
    var change: [String] = []

    func validate() throws {
        guard delta != nil else { throw ValidationError("Give one change, like +1 or -1.") }
    }

    func run() throws {
        try Client.run(.adjustRounds(delta: delta ?? 0))
    }

    private var delta: Int? {
        guard change.count == 1, let delta = Int(change[0]), delta != 0 else { return nil }
        return delta
    }
}

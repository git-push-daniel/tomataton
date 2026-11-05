import ArgumentParser
import Foundation
import TomatoKit

struct Presets: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "List, add or remove presets.",
        subcommands: [List.self, Add.self, Remove.self],
        defaultSubcommand: List.self
    )

    struct List: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "List presets (▸ marks the one in use).")

        @Flag(help: "Print JSON.")
        var json = false

        func run() throws { try printPresets(Client.send(.listPresets), json: json) }
    }

    struct Add: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Add a preset.")

        @Argument(help: "Name. If it's taken, a number is appended.")
        var name: String

        @Option(help: "Focus minutes.")
        var work = Preset.classic.workMinutes

        @Option(name: .customLong("break"), help: "Short break minutes.")
        var shortBreak = Preset.classic.shortBreakMinutes

        @Option(help: "Long break minutes.")
        var long = Preset.classic.longBreakMinutes

        @Option(help: "Focus sessions before each long break.")
        var rounds = Preset.classic.roundsBeforeLongBreak

        @Flag(help: "Start focus sessions automatically after breaks.")
        var autoStartFocus = false

        func run() throws {
            let preset = Preset(name: name, workMinutes: work, shortBreakMinutes: shortBreak,
                                longBreakMinutes: long, roundsBeforeLongBreak: rounds, autoStartWork: autoStartFocus)
            try printPresets(Client.send(.addPreset(preset)), json: false)
        }
    }

    struct Remove: ParsableCommand {
        static let configuration = CommandConfiguration(commandName: "rm", abstract: "Remove a preset.", aliases: ["remove"])

        @Argument(help: "Name (case-insensitive).")
        var name: String

        func run() throws { try printPresets(Client.send(.deletePreset(name: name)), json: false) }
    }
}

private func printPresets(_ response: IPCResponse, json: Bool) throws {
    switch response {
    case .presets(let list): json ? try Output.json(list) : print(Output.text.presets(list))
    case .failure(let message): throw CLIError(message)
    default: throw CLIError("Unexpected reply from the app.")
    }
}

extension StatsRange: @retroactive ExpressibleByArgument {}

struct Stats: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Show focus and rest time for today or this week.")

    @Argument(help: "today or week.")
    var range: StatsRange = .week

    @Flag(help: "Print JSON.")
    var json = false

    func run() throws {
        switch try Client.send(.stats(range)) {
        case .stats(let report): json ? try Output.json(report) : print(Output.text.stats(report))
        case .failure(let message): throw CLIError(message)
        default: throw CLIError("Unexpected reply from the app.")
        }
    }
}

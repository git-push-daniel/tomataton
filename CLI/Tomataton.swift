import ArgumentParser

@main
struct Tomataton: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "tomataton",
        abstract: "Control the Tomataton pomodoro timer from the terminal.",
        discussion: """
        Commands that change the timer launch the app if it isn't running.
        `status` never does, so `tomataton status --short` is safe in a shell prompt.
        """,
        version: "0.1.0",
        subcommands: [
            Status.self, Start.self, Pause.self, Resume.self, Toggle.self, Stop.self, Skip.self, Restart.self,
            Add.self, Rounds.self, Presets.self, Stats.self,
        ],
        defaultSubcommand: Status.self
    )
}

import Foundation
import Observation
import OSLog
import TomatoKit

/// Owns the timer and is the single source of truth for every UI surface.
@MainActor
@Observable
final class AppModel {
    private(set) var engine = TimerEngine(preset: .classic)
    /// Refreshed by the ticker so views that read it re-render the countdown.
    private(set) var now = Date.now
    /// Kept in memory until history is persisted (milestone 4).
    private(set) var records: [SessionRecord] = []
    let presets = Preset.builtIn

    @ObservationIgnored private let notifications = NotificationService()
    @ObservationIgnored private var ticker: Task<Void, Never>?

    var state: TimerState { engine.state }
    var remaining: TimeInterval { state.remaining(at: now) }
    var progress: Double {
        guard state.phaseDuration > 0 else { return 0 }
        return 1 - remaining / state.phaseDuration
    }

    init() {
        notifications.requestAuthorization()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                guard let delay = self?.delayUntilNextSecond else { return }
                try? await Task.sleep(for: delay)
                self?.tick()
            }
        }
    }

    // MARK: - Actions

    func toggle() { apply { engine, now in engine.toggle(now: now); return [] } }
    func skip() { apply { $0.skip(now: $1) } }
    func restart() { apply { $0.restartPhase(now: $1) } }
    func stop() { apply { $0.stop(now: $1) } }

    func adjust(minutes: Int) {
        apply { engine, now in engine.adjust(by: TimeInterval(minutes * 60), now: now); return [] }
    }

    func adjustRounds(by delta: Int) {
        apply { engine, _ in engine.adjustRounds(by: delta); return [] }
    }

    /// Switching preset mid-run restarts the cycle running; otherwise it just prepares it.
    func choose(_ preset: Preset) {
        if state.status == .running {
            apply { $0.start(preset: preset, now: $1) }
        } else {
            apply { $0.select(preset: preset, now: $1) }
        }
    }

    // MARK: - Today

    /// Today's totals, including the phase in progress.
    var today: Totals {
        guard let day = Calendar.current.dateInterval(of: .day, for: now) else { return Totals() }
        // The live phase counts like a stop: its active time, never a completed pomodoro.
        let live = state.record(endingAt: now, outcome: .stopped)
        return Totals(records + (live.map { [$0] } ?? []), in: day)
    }

    // MARK: - Internals

    private func apply(action: String = #function, _ change: (inout TimerEngine, Date) -> [SessionRecord]) {
        let now = Date.now
        let before = state.logDescription(at: now)
        records += change(&engine, now)
        self.now = now
        Logger.timer.notice("\(action, privacy: .public): \(before, privacy: .public) → \(self.state.logDescription(at: now), privacy: .public)")
    }

    private func tick() {
        let now = Date.now
        let before = state.logDescription(at: now)
        let finished = engine.tick(now: now)
        self.now = now
        records += finished
        if !finished.isEmpty {
            Logger.timer.notice("tick: \(before, privacy: .public) → \(self.state.logDescription(at: now), privacy: .public)")
        }
        if let last = finished.last(where: { $0.outcome == .completed }) {
            notifications.phaseFinished(last.phase, next: state)
        }
    }

    /// Wake right after the displayed second changes, so the countdown never skips.
    private var delayUntilNextSecond: Duration {
        guard state.status == .running else { return .seconds(1) }
        let fraction = remaining.truncatingRemainder(dividingBy: 1)
        return .milliseconds(Int((fraction > 0.02 ? fraction : 1) * 1000) + 5)
    }
}

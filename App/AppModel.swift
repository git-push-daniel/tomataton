import Foundation
import Observation
import OSLog
import TomatoKit

/// Owns the timer and is the single source of truth for every UI surface.
@MainActor
@Observable
final class AppModel {
    private(set) var engine: TimerEngine
    private(set) var library: PresetLibrary
    /// Refreshed by the ticker so views that read it re-render the countdown.
    private(set) var now = Date.now
    /// Kept in memory until history is persisted (milestone 4).
    private(set) var records: [SessionRecord] = []

    @ObservationIgnored private let presetStore: JSONFileStore<PresetLibrary>
    @ObservationIgnored private let notifications = NotificationService()
    @ObservationIgnored private var ticker: Task<Void, Never>?

    var state: TimerState { engine.state }
    var presets: [Preset] { library.presets }
    var remaining: TimeInterval { state.remaining(at: now) }
    var progress: Double {
        guard state.phaseDuration > 0 else { return 0 }
        return 1 - remaining / state.phaseDuration
    }

    init() {
        Preferences.registerDefaults()
        let store = JSONFileStore<PresetLibrary>(url: AppPaths.presets)
        let library = Self.loadLibrary(from: store)
        presetStore = store
        self.library = library
        engine = TimerEngine(preset: library.defaultPreset)
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

    // MARK: - Presets

    @discardableResult
    func addPreset() -> Preset {
        changeLibrary { $0.add() }
    }

    /// Saves edits; if the preset is the one in use, the timer picks them up too.
    /// Returns the stored value, whose name may have been made unique.
    @discardableResult
    func updatePreset(_ preset: Preset) -> Preset? {
        guard let stored = changeLibrary({ $0.update(preset) }) else { return nil }
        if stored.id == state.preset.id {
            apply { engine, _ in engine.updatePreset(stored); return [] }
        }
        return stored
    }

    func deletePreset(id: Preset.ID) {
        changeLibrary { $0.delete(id: id) }
    }

    func movePresets(fromOffsets source: IndexSet, toOffset destination: Int) {
        changeLibrary { $0.move(fromOffsets: source, toOffset: destination) }
    }

    func setDefaultPreset(id: Preset.ID) {
        changeLibrary { $0.setDefault(id: id) }
    }

    /// Resets edited built-ins and re-adds deleted ones. Returns the presets that changed.
    @discardableResult
    func restoreBuiltInPresets() -> [Preset] {
        let restored = changeLibrary { $0.restoreBuiltIns() }
        if let inUse = restored.first(where: { $0.id == state.preset.id }) {
            apply { engine, _ in engine.updatePreset(inUse); return [] }
        }
        return restored
    }

    @discardableResult
    private func changeLibrary<Result>(_ change: (inout PresetLibrary) -> Result) -> Result {
        let result = change(&library)
        do {
            try presetStore.save(library)
        } catch {
            Logger.app.error("Couldn't save presets: \(error, privacy: .public)")
        }
        return result
    }

    private static func loadLibrary(from store: JSONFileStore<PresetLibrary>) -> PresetLibrary {
        do {
            let library = try store.load() ?? .standard
            Logger.app.notice("Loaded \(library.presets.count) presets (default: \(library.defaultPreset.name, privacy: .public))")
            return library
        } catch {
            // Keep the unreadable file around instead of overwriting it on the next save.
            let backup = try? store.quarantine()
            Logger.app.error("Couldn't read presets (\(error, privacy: .public)); moved to \(backup?.path ?? "-", privacy: .public)")
            return .standard
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

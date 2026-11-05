import AppKit
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
    /// Today's sessions as loaded at launch, plus every session finished since.
    private(set) var records: [SessionRecord]

    @ObservationIgnored private let presetStore: JSONFileStore<PresetLibrary>
    /// nil if the database couldn't be opened; the app then still works, without history.
    @ObservationIgnored private let history: HistoryStore?
    @ObservationIgnored private let notifications = NotificationService()
    @ObservationIgnored private var ticker: Task<Void, Never>?
    @ObservationIgnored private var systemObservers: [any NSObjectProtocol] = []

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

        let history = Self.openHistory()
        self.history = history
        // Quitting pauses the timer, so it normally comes back paused. After a
        // crash it may come back running; the first tick then records any phase
        // that ended meanwhile (without auto-starting the next, see autoStartGrace).
        engine = Self.restoreEngine(from: history) ?? TimerEngine(preset: library.defaultPreset)
        records = Self.loadTodaysRecords(from: history)

        notifications.requestAuthorization()
        observeSleepAndQuit()
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
        let previous = state
        let finished = change(&engine, now)
        self.now = now
        Logger.timer.notice("\(action, privacy: .public): \(previous.logDescription(at: now), privacy: .public) → \(self.state.logDescription(at: now), privacy: .public)")
        commit(finished, changedFrom: previous)
    }

    private func tick() {
        let now = Date.now
        let previous = state
        let finished = engine.tick(now: now)
        self.now = now
        guard !finished.isEmpty else { return }
        Logger.timer.notice("tick: \(previous.logDescription(at: now), privacy: .public) → \(self.state.logDescription(at: now), privacy: .public)")
        commit(finished, changedFrom: previous)

        // Don't announce phases that ended long ago, e.g. while the app wasn't running.
        if let last = finished.last(where: { $0.outcome == .completed }),
           now.timeIntervalSince(last.endedAt) < 60 {
            notifications.phaseFinished(last.phase, next: state)
        }
    }

    /// Time away from the Mac shouldn't count, so sleeping or quitting pauses a running timer.
    private func observeSleepAndQuit() {
        let pauseOn: [(NotificationCenter, Notification.Name, String)] = [
            (NSWorkspace.shared.notificationCenter, NSWorkspace.willSleepNotification, "sleep"),
            (.default, NSApplication.willTerminateNotification, "quit"),
        ]
        systemObservers = pauseOn.map { center, name, reason in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.pauseIfRunning(reason: reason) }
            }
        }
    }

    private func pauseIfRunning(reason: String) {
        guard state.status == .running else { return }
        // Saves synchronously via commit, so the paused state is on disk before the app exits.
        apply(action: "pause on \(reason)") { engine, now in engine.pause(now: now); return [] }
    }

    /// Records finished sessions and saves the timer state if anything changed.
    private func commit(_ finished: [SessionRecord], changedFrom previous: TimerState) {
        records += finished
        guard !finished.isEmpty || state != previous else { return }
        do {
            try history?.save(state: state, adding: finished)
        } catch {
            Logger.app.error("Couldn't save history: \(error, privacy: .public)")
        }
    }

    private static func openHistory() -> HistoryStore? {
        do {
            return try HistoryStore.open(at: AppPaths.history)
        } catch {
            Logger.app.error("Couldn't open history at \(AppPaths.history.path, privacy: .public): \(error, privacy: .public)")
            return nil
        }
    }

    private static func restoreEngine(from history: HistoryStore?) -> TimerEngine? {
        do {
            guard let state = try history?.loadTimerState() else { return nil }
            Logger.app.notice("Restored timer: \(state.logDescription(at: .now), privacy: .public)")
            return TimerEngine(state: state)
        } catch {
            Logger.app.error("Couldn't restore timer, starting fresh: \(error, privacy: .public)")
            return nil
        }
    }

    private static func loadTodaysRecords(from history: HistoryStore?) -> [SessionRecord] {
        guard let history, let today = Calendar.current.dateInterval(of: .day, for: .now) else { return [] }
        do {
            let records = try history.records(in: today)
            Logger.app.notice("Loaded \(records.count) sessions from today")
            return records
        } catch {
            Logger.app.error("Couldn't load today's sessions: \(error, privacy: .public)")
            return []
        }
    }

    /// Wake right after the displayed second changes, so the countdown never skips.
    private var delayUntilNextSecond: Duration {
        guard state.status == .running else { return .seconds(1) }
        let fraction = remaining.truncatingRemainder(dividingBy: 1)
        return .milliseconds(Int((fraction > 0.02 ? fraction : 1) * 1000) + 5)
    }
}

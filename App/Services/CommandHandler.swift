import Foundation
import OSLog
import TomatoKit

/// Answers requests from the `tomataton` CLI, using the same actions as the UI.
extension AppModel {
    func handle(_ request: IPCRequest) -> IPCResponse {
        refreshNow()
        switch request {
        case .status:
            break
        case .start(let name, let overrides):
            var base = state.preset
            if let name {
                guard let found = library.preset(named: name) else { return .failure(unknownPreset(name)) }
                base = found
            }
            start((overrides ?? PresetOverrides()).applied(to: base))
        case .resume: resume()
        case .pause: pause()
        case .toggle: toggle()
        case .stop: stop()
        case .skip: skip()
        case .restart: restart()
        case .adjust(let seconds): adjust(seconds: seconds)
        case .adjustRounds(let delta): adjustRounds(by: delta)
        case .listPresets:
            return .presets(presetList)
        case .addPreset(let preset):
            addPreset(preset)
            return .presets(presetList)
        case .deletePreset(let name):
            guard let preset = library.preset(named: name) else { return .failure(unknownPreset(name)) }
            guard presets.count > 1 else { return .failure("Can't delete the last preset.") }
            deletePreset(id: preset.id)
            return .presets(presetList)
        case .stats(let range):
            return statsReport(range).map(IPCResponse.stats) ?? .failure("Couldn't work out the dates for \(range).")
        }
        return .status(statusSnapshot)
    }

    var statusSnapshot: StatusSnapshot {
        let day = Calendar.current.dateInterval(of: .day, for: now) ?? DateInterval(start: now, duration: 0)
        return StatusSnapshot(state: state, now: now, today: today, day: day)
    }

    private var presetList: PresetList {
        PresetList(presets: presets, defaultID: library.defaultID,
                   inUseID: library.preset(id: state.preset.id)?.id)
    }

    private func statsReport(_ range: StatsRange) -> StatsReport? {
        let calendar = Calendar.current
        let interval = switch range {
        case .today: calendar.dateInterval(of: .day, for: now)
        case .week: calendar.week(containing: now)
        }
        guard let interval else { return nil }
        var sessions = storedSessions(in: interval)
        if let live = liveRecord, live.startedAt < interval.end, live.endedAt > interval.start {
            sessions.append(live)
        }
        return StatsReport(range: range, interval: interval,
                           days: Totals.daily(sessions, in: interval, calendar: calendar))
    }

    private func unknownPreset(_ name: String) -> String {
        "No preset named “\(name)”. Presets: \(presets.map(\.name).joined(separator: ", "))."
    }

    /// Starts serving CLI requests, unless another running copy of the app already is.
    func startCommandServer() -> UnixSocketServer? {
        let path = AppPaths.socket.path
        if (try? CommandChannel.send(.status, to: path)) != nil {
            Logger.app.notice("Another Tomataton is already serving \(path, privacy: .public); not taking over")
            return nil
        }
        do {
            let server = try CommandChannel.serve(at: path) { [weak self] request in
                guard let self else { return .failure("Tomataton is quitting.") }
                return await self.handle(request)
            }
            Logger.app.notice("Listening for CLI commands at \(path, privacy: .public)")
            return server
        } catch {
            Logger.app.error("Couldn't start the command socket: \(error, privacy: .public)")
            return nil
        }
    }
}

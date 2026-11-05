#if DEBUG
import AppKit

/// Debug-only tooling for checking layout without looking at the screen.
///
/// - `TOMATATON_SECTION=stats` opens the main window on that section.
/// - `TOMATATON_SAMPLE_HISTORY=1` adds sample history if there are no sessions yet.
/// - `TOMATATON_HOVER_DAY=0…6` shows the stats chart's hover tooltip for that day.
/// - `TOMATATON_SNAPSHOT_DIR=/path` saves the main window as
///   `<name>-light.png` and `<name>-dark.png` (name from `TOMATATON_SNAPSHOT_NAME`)
///   and quits. Combine with `TOMATATON_SUPPORT_DIR` to keep real data out of it.
enum DebugSnapshot {
    private static var environment: [String: String] { ProcessInfo.processInfo.environment }

    static var initialSection: String? { environment["TOMATATON_SECTION"] }
    static var wantsSampleHistory: Bool { environment["TOMATATON_SAMPLE_HISTORY"] == "1" }
    /// `TOMATATON_HOVER_DAY=0…6` shows the stats chart's hover tooltip for that day.
    static var hoveredDayIndex: Int? { environment["TOMATATON_HOVER_DAY"].flatMap(Int.init) }

    @MainActor
    static func runIfRequested() {
        guard let directory = environment["TOMATATON_SNAPSHOT_DIR"] else { return }
        let name = environment["TOMATATON_SNAPSHOT_NAME"] ?? "window"
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            for (appearance, suffix) in [(NSAppearance.Name.aqua, "light"), (.darkAqua, "dark")] {
                NSApp.appearance = NSAppearance(named: appearance)
                try? await Task.sleep(for: .seconds(1))
                guard let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "main" }),
                      let view = window.contentView?.superview ?? window.contentView,
                      let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds)
                else { continue }
                view.cacheDisplay(in: view.bounds, to: bitmap)
                let url = URL(filePath: directory).appending(path: "\(name)-\(suffix).png")
                try? bitmap.representation(using: .png, properties: [:])?.write(to: url)
            }
            NSApp.terminate(nil)
        }
    }
}
#endif

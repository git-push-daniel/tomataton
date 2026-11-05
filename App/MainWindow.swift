import SwiftUI

struct MainWindow: View {
    enum Section: String, CaseIterable, Identifiable {
        case timer = "Timer"
        case stats = "Stats"
        case presets = "Presets"

        var id: Self { self }

        var symbol: String {
            switch self {
            case .timer: "timer"
            case .stats: "chart.bar.xaxis"
            case .presets: "slider.horizontal.3"
            }
        }
    }

    static let minSize = CGSize(width: 620, height: 500)
    static let maxSize = CGSize(width: 720, height: 540)
    static let sidebarWidth: CGFloat = 170

    @State private var selection: Section = .timer

    var body: some View {
        NavigationSplitView {
            List(Section.allCases, selection: $selection) { section in
                Label(section.rawValue, systemImage: section.symbol)
            }
            .navigationSplitViewColumnWidth(min: 150, ideal: Self.sidebarWidth)
        } detail: {
            detail
                // The split view sizes the window from its columns, so the default width is set here.
                .navigationSplitViewColumnWidth(min: Self.minSize.width - Self.sidebarWidth,
                                                ideal: Self.maxSize.width - Self.sidebarWidth)
        }
        .frame(minWidth: Self.minSize.width, idealWidth: Self.maxSize.width, maxWidth: Self.maxSize.width,
               minHeight: Self.minSize.height, idealHeight: Self.maxSize.height, maxHeight: Self.maxSize.height)
    }

    @ViewBuilder private var detail: some View {
        switch selection {
        case .timer:
            TimerView()
        case .stats:
            ContentUnavailableView("Stats", systemImage: Section.stats.symbol,
                                   description: Text("Daily and weekly charts are coming in milestone 5."))
        case .presets:
            PresetsView()
        }
    }
}

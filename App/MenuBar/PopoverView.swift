import SwiftUI

struct PopoverView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(model.state.phase.displayName.uppercased())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(model.state.phase.tint)
                Spacer()
                RoundDots()
            }

            CountdownText(size: 48)
                .frame(maxWidth: .infinity)

            ProgressView(value: model.progress)
                .tint(model.state.phase.tint)

            TimerControls()
                .frame(maxWidth: .infinity)

            QuickAdjust()
            PresetChips()

            Divider()
            TodayStrip()
            Divider()

            HStack {
                Button("Open Tomataton") {
                    openWindow(id: WindowID.main)
                    NSApp.activate()
                }
                Spacer()
                Button("Settings…") {
                    NSApp.activate()
                    openSettings()
                }
                .keyboardShortcut(",")
                Button("Quit") { NSApp.terminate(nil) }
                    .keyboardShortcut("q")
            }
            .buttonStyle(.borderless)
        }
        .padding(16)
        .frame(width: 340)
    }
}

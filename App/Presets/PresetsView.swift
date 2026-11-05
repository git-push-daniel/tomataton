import SwiftUI
import TomatoKit

/// The "Presets" section of the main window: list on the left, editor on the right.
struct PresetsView: View {
    @Environment(AppModel.self) private var model
    @State private var selection: Preset.ID?
    @State private var isConfirmingRestore = false

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                List(selection: $selection) {
                    ForEach(model.presets) { preset in
                        PresetRow(
                            preset: preset,
                            isDefault: preset.id == model.library.defaultID,
                            isInUse: preset.id == model.state.preset.id
                        )
                        .tag(preset.id)
                    }
                    .onMove { model.movePresets(fromOffsets: $0, toOffset: $1) }
                }
                Divider()
                listToolbar
            }
            .frame(width: 190)

            Divider()

            if let id = selection, let preset = model.library.preset(id: id) {
                PresetEditor(preset: preset)
                    .id(id)
            } else {
                ContentUnavailableView("No Preset Selected", systemImage: "slider.horizontal.3",
                                       description: Text("Select a preset to edit it."))
            }
        }
        .onAppear {
            if selection == nil {
                let inUse = model.library.preset(id: model.state.preset.id)
                selection = (inUse ?? model.library.defaultPreset).id
            }
        }
    }

    private var listToolbar: some View {
        HStack(spacing: 2) {
            Group {
                Button("Add Preset", systemImage: "plus") {
                    selection = model.addPreset().id
                }
                .help("Add a preset")
                Button("Delete Preset", systemImage: "minus") {
                    guard let id = selection else { return }
                    let index = model.presets.firstIndex { $0.id == id } ?? 0
                    model.deletePreset(id: id)
                    selection = model.presets[min(index, model.presets.count - 1)].id
                }
                .disabled(selection == nil || model.presets.count <= 1)
                .help("Delete the selected preset")
            }
            .labelStyle(.iconOnly)
            Spacer()
            let toRestore = model.library.builtInsToRestore
            Button("Restore Built-ins") {
                // Only ask when edits would be thrown away; re-adding deleted ones is harmless.
                if model.library.editedBuiltIns.isEmpty {
                    restoreBuiltIns()
                } else {
                    isConfirmingRestore = true
                }
            }
            .font(.callout)
            .disabled(toRestore.isEmpty)
            .help(toRestore.isEmpty
                  ? "Classic, Deep and Quick are unchanged"
                  : "Restore \(toRestore.map(\.name).formatted(.list(type: .and))) to the original values")
        }
        .buttonStyle(BarButtonStyle())
        .confirmationDialog("Restore built-in presets?", isPresented: $isConfirmingRestore) {
            Button("Restore", role: .destructive, action: restoreBuiltIns)
        } message: {
            let edited = model.library.editedBuiltIns.map(\.name).formatted(.list(type: .and))
            Text("Your changes to \(edited) will be replaced with the original values.")
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
    }

    private func restoreBuiltIns() {
        if let first = model.restoreBuiltInPresets().first {
            selection = first.id
        }
    }
}

private struct PresetRow: View {
    let preset: Preset
    let isDefault: Bool
    let isInUse: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text(preset.name).lineLimit(1)
                if isDefault {
                    Text("Default")
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 4)
                        .background(.quaternary, in: .capsule)
                }
                Spacer(minLength: 0)
                if isInUse {
                    Image(systemName: "timer")
                        .foregroundStyle(Phase.work.tint)
                        .help("In use")
                }
            }
            HStack(spacing: 4) {
                if preset.isBuiltIn {
                    Image(systemName: "shippingbox")
                        .help("Built-in preset")
                        .accessibilityLabel("Built-in")
                }
                Text("\(preset.workMinutes)/\(preset.shortBreakMinutes)/\(preset.longBreakMinutes) min  ×\(preset.roundsBeforeLongBreak)")
                    .monospacedDigit()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

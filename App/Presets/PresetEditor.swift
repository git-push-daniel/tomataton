import SwiftUI
import TomatoKit

/// Edits one preset. Every change is saved immediately, except the name,
/// which is saved when you press Return or leave the field (so it isn't
/// renamed to "Deep 2" halfway through typing "Deep…").
struct PresetEditor: View {
    @Environment(AppModel.self) private var model
    let preset: Preset

    @State private var name: String
    @FocusState private var isNameFocused: Bool

    init(preset: Preset) {
        self.preset = preset
        _name = State(initialValue: preset.name)
    }

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $name)
                    .focused($isNameFocused)
                    .onSubmit(commitName)
                    .onChange(of: isNameFocused) { _, focused in
                        if !focused { commitName() }
                    }
            } footer: {
                if preset.isBuiltIn {
                    Label("Built-in preset. Restore Built-ins brings back its original values.",
                          systemImage: "shippingbox")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                minutesRow("Focus", \.workMinutes, in: Preset.workRange)
                minutesRow("Short break", \.shortBreakMinutes, in: Preset.shortBreakRange)
                minutesRow("Long break", \.longBreakMinutes, in: Preset.longBreakRange)
                numberRow("Rounds", \.roundsBeforeLongBreak, in: Preset.roundsRange, unit: nil)
            } footer: {
                Text("Focus sessions before each long break.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Auto-start") {
                Toggle("Start breaks automatically", isOn: binding(\.autoStartBreaks))
                Toggle("Start focus sessions automatically", isOn: binding(\.autoStartWork))
            }

            Section {
                HStack {
                    Button("Set as Default") { model.setDefaultPreset(id: preset.id) }
                        .disabled(preset.id == model.library.defaultID)
                    Spacer()
                    Button("Use Now") { model.choose(preset) }
                        .disabled(preset.id == model.state.preset.id)
                }
            } footer: {
                if preset.id == model.state.preset.id {
                    Text("In use: changes apply from the next phase.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .onDisappear(perform: commitName)
        // Pick up renames made elsewhere (e.g. "Restore Built-in Presets"),
        // so the stale local copy isn't saved back over them.
        .onChange(of: model.library.preset(id: preset.id)?.name) { _, storedName in
            if !isNameFocused, let storedName { name = storedName }
        }
    }

    // MARK: - Rows

    private func minutesRow(_ title: String, _ keyPath: WritableKeyPath<Preset, Int>,
                            in range: ClosedRange<Int>) -> some View {
        numberRow(title, keyPath, in: range, unit: "min")
    }

    private func numberRow(_ title: String, _ keyPath: WritableKeyPath<Preset, Int>,
                           in range: ClosedRange<Int>, unit: String?) -> some View {
        let value = binding(keyPath)
        return LabeledContent(title) {
            HStack(spacing: 6) {
                TextField(title, value: value, format: .number)
                    .labelsHidden()
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .frame(width: 44)
                if let unit {
                    Text(unit).foregroundStyle(.secondary)
                }
                Stepper(title, value: value, in: range)
                    .labelsHidden()
            }
        }
    }

    // MARK: - Saving

    /// Reads the latest stored preset and writes one field back.
    private func binding<Value>(_ keyPath: WritableKeyPath<Preset, Value>) -> Binding<Value> {
        Binding {
            (model.library.preset(id: preset.id) ?? preset)[keyPath: keyPath]
        } set: { newValue in
            guard var current = model.library.preset(id: preset.id) else { return }
            current[keyPath: keyPath] = newValue
            model.updatePreset(current)
        }
    }

    private func commitName() {
        guard var current = model.library.preset(id: preset.id), current.name != name else { return }
        current.name = name
        if let stored = model.updatePreset(current) {
            name = stored.name  // may have been trimmed or made unique
        }
    }
}

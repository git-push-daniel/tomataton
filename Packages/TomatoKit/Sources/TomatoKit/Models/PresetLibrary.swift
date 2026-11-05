import Foundation

/// The user's ordered list of presets plus which one is the default.
///
/// Invariants, kept by every initializer and mutation:
/// - there is always at least one preset
/// - `defaultID` names one of them
/// - every preset is `sanitized()` and names are unique (case-insensitive)
public struct PresetLibrary: Codable, Sendable, Equatable {
    public private(set) var presets: [Preset]
    public private(set) var defaultID: Preset.ID

    public static let standard = PresetLibrary(presets: Preset.builtIn, defaultID: Preset.classic.id)

    public init(presets: [Preset], defaultID: Preset.ID?) {
        var library = PresetLibrary(unchecked: [], defaultID: Preset.classic.id)
        for preset in presets where library.preset(id: preset.id) == nil {
            library.presets.append(library.cleaned(preset))
        }
        if library.presets.isEmpty { library.presets = Preset.builtIn }
        library.defaultID = defaultID.flatMap { library.preset(id: $0)?.id } ?? library.presets[0].id
        self = library
    }

    private init(unchecked presets: [Preset], defaultID: Preset.ID) {
        self.presets = presets
        self.defaultID = defaultID
    }

    // Decoded data goes through the validating initializer, so a hand-edited
    // or older file can never break the invariants.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            presets: try container.decode([Preset].self, forKey: .presets),
            defaultID: try container.decodeIfPresent(Preset.ID.self, forKey: .defaultID)
        )
    }

    // MARK: - Lookup

    public var defaultPreset: Preset { preset(id: defaultID) ?? presets[0] }

    public func preset(id: Preset.ID) -> Preset? {
        presets.first { $0.id == id }
    }

    /// Case-insensitive lookup, e.g. for `tomataton start deep`.
    public func preset(named name: String) -> Preset? {
        let wanted = name.trimmingCharacters(in: .whitespaces)
        return presets.first { $0.name.caseInsensitiveCompare(wanted) == .orderedSame }
    }

    // MARK: - Mutations

    /// Adds `preset`, or a new one based on the default preset when nil.
    @discardableResult
    public mutating func add(_ preset: Preset? = nil) -> Preset {
        var new = preset ?? defaultPreset
        if preset == nil {
            new.name = "Custom"
        }
        if self.preset(id: new.id) != nil || preset == nil {
            new.id = UUID()
        }
        new = cleaned(new)
        presets.append(new)
        return new
    }

    /// Replaces the preset with the same id. Returns the stored (cleaned) value.
    @discardableResult
    public mutating func update(_ preset: Preset) -> Preset? {
        guard let index = presets.firstIndex(where: { $0.id == preset.id }) else { return nil }
        let stored = cleaned(preset)
        presets[index] = stored
        return stored
    }

    /// Deletes a preset. The last remaining preset can't be deleted.
    @discardableResult
    public mutating func delete(id: Preset.ID) -> Bool {
        guard presets.count > 1, let index = presets.firstIndex(where: { $0.id == id }) else { return false }
        presets.remove(at: index)
        if defaultID == id { defaultID = presets[0].id }
        return true
    }

    public mutating func setDefault(id: Preset.ID) {
        guard preset(id: id) != nil else { return }
        defaultID = id
    }

    /// Same semantics as SwiftUI's `move(fromOffsets:toOffset:)`, so it can back `List.onMove`.
    public mutating func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        let moving = source.sorted().map { presets[$0] }
        let insertAt = destination - source.count(in: 0..<destination)
        for index in source.sorted(by: >) { presets.remove(at: index) }
        presets.insert(contentsOf: moving, at: insertAt)
    }

    /// Built-in presets that were deleted or edited.
    public var builtInsToRestore: [Preset] {
        Preset.builtIn.filter { preset(id: $0.id) != cleaned($0) }
    }

    /// Built-in presets that still exist but were edited.
    public var editedBuiltIns: [Preset] {
        builtInsToRestore.filter { preset(id: $0.id) != nil }
    }

    /// Resets edited built-ins to their original values (in place) and re-adds
    /// deleted ones at their original positions (Classic first, …).
    /// Returns the presets that changed, as stored.
    @discardableResult
    public mutating func restoreBuiltIns() -> [Preset] {
        var restored: [Preset] = []
        for (index, builtIn) in Preset.builtIn.enumerated() {
            let original = cleaned(builtIn)
            if let existing = presets.firstIndex(where: { $0.id == builtIn.id }) {
                guard presets[existing] != original else { continue }
                presets[existing] = original
            } else {
                presets.insert(original, at: Swift.min(index, presets.count))
            }
            restored.append(original)
        }
        return restored
    }

    // MARK: - Internals

    /// Sanitizes values and makes the name unique among the *other* presets.
    private func cleaned(_ preset: Preset) -> Preset {
        var result = preset.sanitized()
        let taken = Set(presets.filter { $0.id != preset.id }.map { $0.name.lowercased() })
        let base = result.name
        var suffix = 2
        while taken.contains(result.name.lowercased()) {
            let tail = " \(suffix)"
            result.name = String(base.prefix(Preset.maximumNameLength - tail.count)) + tail
            suffix += 1
        }
        return result
    }
}

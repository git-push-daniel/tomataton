import Foundation
import Testing
@testable import TomatoKit

@Suite struct PresetLibraryTests {
    @Test func standardLibraryHasBuiltInsWithClassicDefault() {
        let library = PresetLibrary.standard
        #expect(library.presets == Preset.builtIn)
        #expect(library.defaultPreset == .classic)
    }

    @Test func emptyLibraryFallsBackToBuiltIns() {
        let library = PresetLibrary(presets: [], defaultID: nil)
        #expect(library.presets == Preset.builtIn)
    }

    @Test func unknownDefaultFallsBackToFirstPreset() {
        let library = PresetLibrary(presets: [.deep, .quick], defaultID: UUID())
        #expect(library.defaultPreset == .deep)
    }

    @Test func initDropsDuplicateIDsAndRenamesDuplicateNames() {
        var twin = Preset.quick
        twin.id = UUID()
        twin.name = "CLASSIC"
        let library = PresetLibrary(presets: [.classic, .classic, twin], defaultID: nil)

        #expect(library.presets.count == 2)
        #expect(library.presets[1].name == "CLASSIC 2")
    }

    @Test func addWithoutArgumentCopiesDefaultUnderNewName() {
        var library = PresetLibrary.standard
        let first = library.add()
        let second = library.add()

        #expect(first.name == "Custom")
        #expect(second.name == "Custom 2")
        #expect(first.id != Preset.classic.id)
        #expect(first.workMinutes == Preset.classic.workMinutes)
        #expect(library.presets.count == 5)
    }

    @Test func addingExistingIDGetsFreshID() {
        var library = PresetLibrary.standard
        let added = library.add(.deep)
        #expect(added.id != Preset.deep.id)
        #expect(added.name == "Deep 2")
    }

    @Test func updateSanitizesAndKeepsNamesUnique() {
        var library = PresetLibrary.standard
        var edited = Preset.quick
        edited.name = "  deep "
        edited.workMinutes = 999
        edited.roundsBeforeLongBreak = 0

        let stored = library.update(edited)
        #expect(stored?.name == "deep 2")
        #expect(stored?.workMinutes == Preset.workRange.upperBound)
        #expect(stored?.roundsBeforeLongBreak == 1)
        #expect(library.preset(id: Preset.quick.id) == stored)
    }

    @Test func updateKeepsOwnNameWhenUnchanged() {
        var library = PresetLibrary.standard
        var edited = Preset.deep
        edited.workMinutes = 45
        #expect(library.update(edited)?.name == "Deep")
    }

    @Test func updateOfUnknownPresetIsIgnored() {
        var library = PresetLibrary.standard
        let stranger = Preset(name: "Stranger", workMinutes: 1, shortBreakMinutes: 1, longBreakMinutes: 1,
                              roundsBeforeLongBreak: 1)
        #expect(library.update(stranger) == nil)
        #expect(library == .standard)
    }

    @Test func deleteReassignsDefaultAndRefusesLastPreset() {
        var library = PresetLibrary.standard
        let deletedClassic = library.delete(id: Preset.classic.id)
        #expect(deletedClassic)
        #expect(library.defaultPreset == .deep)
        let deletedDeep = library.delete(id: Preset.deep.id)
        #expect(deletedDeep)
        let deletedLast = library.delete(id: Preset.quick.id)
        #expect(!deletedLast)
        #expect(library.presets == [.quick])
    }

    @Test func setDefaultIgnoresUnknownID() {
        var library = PresetLibrary.standard
        library.setDefault(id: Preset.quick.id)
        library.setDefault(id: UUID())
        #expect(library.defaultPreset == .quick)
    }

    @Test(arguments: [
        (IndexSet([0]), 3, ["Deep", "Quick", "Classic"]),
        (IndexSet([2]), 0, ["Quick", "Classic", "Deep"]),
        (IndexSet([0, 1]), 3, ["Quick", "Classic", "Deep"]),
        (IndexSet([1]), 1, ["Classic", "Deep", "Quick"]),
    ])
    func moveMatchesSwiftUISemantics(source: IndexSet, destination: Int, expected: [String]) {
        var library = PresetLibrary.standard
        library.move(fromOffsets: source, toOffset: destination)
        #expect(library.presets.map(\.name) == expected)
    }

    @Test func lookupByNameIsCaseInsensitive() {
        #expect(PresetLibrary.standard.preset(named: " deep ") == .deep)
        #expect(PresetLibrary.standard.preset(named: "nope") == nil)
    }

    @Test func restoreResetsEditedAndReaddsDeletedBuiltIns() {
        var library = PresetLibrary.standard
        var edited = Preset.classic
        edited.name = "My Classic"
        edited.workMinutes = 21
        edited.autoStartWork = true
        library.update(edited)
        library.delete(id: Preset.deep.id)
        #expect(library.builtInsToRestore == [.classic, .deep])
        #expect(library.editedBuiltIns == [.classic])

        let restored = library.restoreBuiltIns()
        #expect(restored == [.classic, .deep])
        #expect(library.builtInsToRestore.isEmpty)
        #expect(library == .standard)
    }

    @Test func restoreLeavesCustomPresetsAndOrderAlone() {
        var library = PresetLibrary.standard
        let custom = library.add()
        var edited = Preset.quick
        edited.workMinutes = 5
        library.update(edited)
        library.move(fromOffsets: [2], toOffset: 0)  // Quick first

        library.restoreBuiltIns()
        #expect(library.presets.map(\.name) == ["Quick", "Classic", "Deep", "Custom"])
        #expect(library.preset(id: Preset.quick.id) == .quick)
        #expect(library.preset(id: custom.id) == custom)
    }

    @Test func restoredBuiltInsGoBackToTheirOriginalPositions() {
        // The situation from the app: Classic deleted, a custom preset added.
        var library = PresetLibrary.standard
        library.delete(id: Preset.classic.id)
        library.add(Preset(name: "Extreme", workMinutes: 90, shortBreakMinutes: 10, longBreakMinutes: 30,
                           roundsBeforeLongBreak: 5))
        library.restoreBuiltIns()
        #expect(library.presets.map(\.name) == ["Classic", "Deep", "Quick", "Extreme"])

        // With everything deleted but a custom preset, built-ins come back in order, first.
        for builtIn in Preset.builtIn { library.delete(id: builtIn.id) }
        library.restoreBuiltIns()
        #expect(library.presets.map(\.name) == ["Classic", "Deep", "Quick", "Extreme"])
    }

    @Test func restoringWithNothingMissingChangesNothing() {
        var library = PresetLibrary.standard
        #expect(library.restoreBuiltIns().isEmpty)
        #expect(library == .standard)
    }

    @Test func restoredBuiltInAvoidsNameClash() {
        var library = PresetLibrary.standard
        library.delete(id: Preset.deep.id)
        var custom = Preset.quick
        custom.id = UUID()
        custom.name = "Deep"
        library.add(custom)
        #expect(library.restoreBuiltIns().first?.name == "Deep 2")
        // Once restored under the unique name, it no longer counts as needing a restore.
        #expect(library.builtInsToRestore.isEmpty)
        #expect(library.restoreBuiltIns().isEmpty)
    }

    @Test func decodingRepairsInvalidData() throws {
        let json = """
        {"defaultID": "11111111-1111-1111-1111-111111111111",
         "presets": [{"id": "22222222-2222-2222-2222-222222222222", "name": "", "workMinutes": 0,
                      "shortBreakMinutes": 500, "longBreakMinutes": 10, "roundsBeforeLongBreak": 99,
                      "autoStartBreaks": true, "autoStartWork": false}]}
        """
        let library = try JSONDecoder().decode(PresetLibrary.self, from: Data(json.utf8))
        let preset = try #require(library.presets.first)

        #expect(library.defaultID == preset.id)
        #expect(preset.name == "Untitled")
        #expect(preset.workMinutes == 1)
        #expect(preset.shortBreakMinutes == Preset.shortBreakRange.upperBound)
        #expect(preset.roundsBeforeLongBreak == TimerEngine.maximumRounds)
    }

    @Test func survivesJSONRoundTrip() throws {
        var library = PresetLibrary.standard
        library.add()
        library.setDefault(id: Preset.deep.id)
        let data = try JSONEncoder().encode(library)
        #expect(try JSONDecoder().decode(PresetLibrary.self, from: data) == library)
    }
}

@Suite struct PresetSanitizingTests {
    @Test func trimsAndTruncatesName() {
        let long = String(repeating: "x", count: 50)
        #expect(Preset(name: "  Focus  ", workMinutes: 25, shortBreakMinutes: 5, longBreakMinutes: 15,
                       roundsBeforeLongBreak: 4).sanitized().name == "Focus")
        #expect(Preset(name: long, workMinutes: 25, shortBreakMinutes: 5, longBreakMinutes: 15,
                       roundsBeforeLongBreak: 4).sanitized().name.count == Preset.maximumNameLength)
    }

    @Test func uniqueSuffixFitsWithinNameLimit() {
        let long = String(repeating: "x", count: Preset.maximumNameLength)
        let first = Preset(name: long, workMinutes: 25, shortBreakMinutes: 5, longBreakMinutes: 15,
                           roundsBeforeLongBreak: 4)
        var library = PresetLibrary(presets: [first], defaultID: nil)
        let copy = library.add(first)
        #expect(copy.name.count == Preset.maximumNameLength)
        #expect(copy.name.hasSuffix(" 2"))
    }

    @Test func validPresetIsUnchanged() {
        #expect(Preset.classic.sanitized() == .classic)
    }
}

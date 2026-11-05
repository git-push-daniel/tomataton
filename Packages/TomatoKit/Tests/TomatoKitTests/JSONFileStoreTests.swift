import Foundation
import Testing
import TomatoKit

@Suite struct JSONFileStoreTests {
    /// A fresh store in its own temporary directory (which doesn't exist yet).
    private func makeStore() -> JSONFileStore<PresetLibrary> {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "TomatoKitTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        return JSONFileStore(url: directory.appending(path: "nested/presets.json"))
    }

    @Test func missingFileLoadsAsNil() throws {
        #expect(try makeStore().load() == nil)
    }

    @Test func saveCreatesDirectoriesAndRoundTrips() throws {
        let store = makeStore()
        var library = PresetLibrary.standard
        library.add()
        try store.save(library)
        #expect(try store.load() == library)
    }

    @Test func corruptFileThrowsAndCanBeQuarantined() throws {
        let store = makeStore()
        try store.save(.standard)
        try Data("not json".utf8).write(to: store.url)

        #expect(throws: (any Error).self) { try store.load() }
        let backup = try store.quarantine()
        #expect(FileManager.default.fileExists(atPath: backup.path))
        #expect(try store.load() == nil)
    }
}

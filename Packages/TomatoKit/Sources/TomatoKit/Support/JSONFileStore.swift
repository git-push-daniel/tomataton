import Foundation

/// Reads and writes one Codable value as a human-readable JSON file.
public struct JSONFileStore<Value: Codable>: Sendable {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    /// The stored value, or nil if the file doesn't exist yet.
    /// Throws if the file exists but can't be read or decoded.
    public func load() throws -> Value? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(Value.self, from: data)
    }

    /// Writes atomically, creating the parent directory if needed.
    public func save(_ value: Value) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(value)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }

    /// Moves an unreadable file aside (e.g. `presets.json` → `presets.json.bak`)
    /// so a fresh save doesn't destroy data a newer version might still read.
    @discardableResult
    public func quarantine() throws -> URL {
        let backup = url.appendingPathExtension("bak")
        try? FileManager.default.removeItem(at: backup)
        try FileManager.default.moveItem(at: url, to: backup)
        return backup
    }
}

public enum AppPaths {
    /// `~/Library/Application Support/Tomataton`, shared by the app and (later) the CLI.
    public static var supportDirectory: URL {
        URL.applicationSupportDirectory.appending(path: "Tomataton", directoryHint: .isDirectory)
    }

    public static var presets: URL { supportDirectory.appending(path: "presets.json") }
}

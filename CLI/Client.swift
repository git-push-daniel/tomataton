import AppKit
import ArgumentParser
import Foundation
import TomatoKit

/// Talks to the app, launching it first when needed.
enum Client {
    /// Sends `request`. If the app isn't running and `launching` is true, starts
    /// it in the background and retries until it answers.
    static func send(_ request: IPCRequest, launching: Bool = true) throws -> IPCResponse {
        do {
            return try CommandChannel.send(request)
        } catch UnixSocketError.notRunning where launching {
            try AppLauncher.launch()
            let deadline = Date.now.addingTimeInterval(10)
            while Date.now < deadline {
                Thread.sleep(forTimeInterval: 0.2)
                do {
                    return try CommandChannel.send(request)
                } catch UnixSocketError.notRunning {
                    continue  // still starting up; nothing was sent, so retrying is safe
                }
            }
            throw CLIError("Launched Tomataton, but it didn't respond.")
        } catch let error as UnixSocketError {
            throw CLIError(error.description)
        }
    }

    /// Sends `request` and prints the resulting status (or the failure).
    static func run(_ request: IPCRequest) throws {
        switch try send(request) {
        case .status(let status): print(Output.text.status(status))
        case .failure(let message): throw CLIError(message)
        default: throw CLIError("Unexpected reply from the app.")
        }
    }
}

struct CLIError: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

enum Output {
    /// Colored bars only when writing to a terminal and NO_COLOR isn't set.
    static let text = CLIText(color: isatty(STDOUT_FILENO) != 0 && ProcessInfo.processInfo.environment["NO_COLOR"] == nil)

    static func json(_ value: some Encodable) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        print(String(decoding: try encoder.encode(value), as: UTF8.self))
    }
}

enum AppLauncher {
    static let bundleIdentifier = "com.tomataton.Tomataton"

    /// Prefers the app this CLI ships inside (Tomataton.app/Contents/Helpers/tomataton,
    /// possibly reached through a symlink), else whatever copy macOS knows about.
    static var appURL: URL? {
        if let executable = Bundle.main.executableURL?.resolvingSymlinksInPath() {
            let bundle = executable.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            if bundle.pathExtension == "app" { return bundle }
        }
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
    }

    /// Opens the app in the menu bar only (no window, not in front), passing
    /// along TOMATATON_SUPPORT_DIR so a test data folder is honored.
    static func launch() throws {
        guard let appURL else { throw CLIError("Couldn't find Tomataton.app.") }
        var arguments = ["-g", "-a", appURL.path]
        if let supportDir = ProcessInfo.processInfo.environment["TOMATATON_SUPPORT_DIR"] {
            // A separate data folder means a separate instance (`-n`); without it
            // `open` would just wake the already-running app using the real data.
            arguments += ["-n", "--env", "TOMATATON_SUPPORT_DIR=\(supportDir)"]
        }
        arguments += ["--args", "--background"]  // must come last
        let open = Process()
        open.executableURL = URL(filePath: "/usr/bin/open")
        open.arguments = arguments
        try open.run()
        open.waitUntilExit()
        guard open.terminationStatus == 0 else { throw CLIError("Couldn't launch \(appURL.path).") }
    }
}

import Foundation

/// Typed layer over the socket: `IPCRequest` in, `IPCResponse` out.
public enum CommandChannel {
    /// Serves requests at `path` until the returned server is stopped.
    public static func serve(
        at path: String, handler: @escaping @Sendable (IPCRequest) async -> IPCResponse
    ) throws -> UnixSocketServer {
        try UnixSocketServer(path: path) { data in
            let response: IPCResponse
            do {
                response = await handler(try IPCCoding.decoder().decode(IPCRequest.self, from: data))
            } catch {
                response = .failure("Unrecognized request; the CLI and the app may be different versions.")
            }
            return (try? IPCCoding.encoder().encode(response)) ?? Data()
        }
    }

    /// Sends one request to the app. Throws `UnixSocketError.notRunning` if it isn't running.
    public static func send(_ request: IPCRequest, to path: String = AppPaths.socket.path) throws -> IPCResponse {
        let reply = try UnixSocketClient.send(try IPCCoding.encoder().encode(request), to: path)
        return try IPCCoding.decoder().decode(IPCResponse.self, from: reply)
    }
}

extension AppPaths {
    /// The app's command socket. It lives in the per-user temporary folder
    /// (socket paths are limited to 104 bytes, which a long
    /// `TOMATATON_SUPPORT_DIR` could exceed), named after the support folder
    /// so instances using different data folders don't collide.
    public static var socket: URL {
        let name = "tomataton-\(stableHash(supportDirectory.standardizedFileURL.path)).sock"
        return URL(filePath: NSTemporaryDirectory()).appending(path: name)
    }

    /// FNV-1a, because `hashValue` differs between processes.
    static func stableHash(_ string: String) -> String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x0000_0100_0000_01b3
        }
        return String(hash, radix: 16)
    }
}

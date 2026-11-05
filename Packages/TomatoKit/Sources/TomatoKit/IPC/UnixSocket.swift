import Foundation

/// Minimal request/response over a Unix domain socket: the client connects,
/// sends one newline-terminated message, and reads one newline-terminated
/// reply. Plain POSIX calls; no dependencies.
public enum UnixSocketError: Error, Equatable, CustomStringConvertible {
    /// Nothing is listening at the path (the app isn't running).
    case notRunning
    case pathTooLong(String)
    case system(String, errno: Int32)
    case emptyReply

    public var description: String {
        switch self {
        case .notRunning: "Tomataton isn't running"
        case .pathTooLong(let path): "Socket path is too long: \(path)"
        case .system(let call, let code): "\(call) failed: \(String(cString: strerror(code)))"
        case .emptyReply: "The app closed the connection without replying"
        }
    }
}

/// Accepts connections and answers each with `handler`.
public final class UnixSocketServer: @unchecked Sendable {
    // Immutable after init; the dispatch source serializes accepts.
    private let fd: Int32
    private let path: String
    private let source: any DispatchSourceRead

    /// Binds `path` (replacing a stale socket file) and starts serving.
    /// The socket is only accessible to the current user (mode 0600).
    public init(path: String, handler: @escaping @Sendable (Data) async -> Data) throws {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw UnixSocketError.system("socket", errno: errno) }
        var address = try Self.address(for: path)
        unlink(path)
        let bound = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bound == 0 else {
            let code = errno
            close(fd)
            throw UnixSocketError.system("bind", errno: code)
        }
        chmod(path, 0o600)
        guard listen(fd, 16) == 0 else {
            let code = errno
            close(fd)
            throw UnixSocketError.system("listen", errno: code)
        }
        _ = fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) | O_NONBLOCK)

        self.fd = fd
        self.path = path
        let queue = DispatchQueue(label: "com.tomataton.socket")
        // Blocking reads and writes happen on GCD threads, never on Swift
        // concurrency's small cooperative pool; only the handler runs there.
        let io = DispatchQueue(label: "com.tomataton.socket.io", attributes: .concurrent)
        source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
        source.setEventHandler {
            // Drain all pending connections; accept fails with EAGAIN when done.
            while case let client = accept(fd, nil, nil), client >= 0 {
                Self.configure(client)
                io.async {
                    let request = Self.readLine(from: client)
                    Task {
                        let reply = await handler(request)
                        io.async {
                            Self.writeLine(reply, to: client)
                            close(client)
                        }
                    }
                }
            }
        }
        source.setCancelHandler {
            close(fd)
            unlink(path)
        }
        source.resume()
    }

    /// Stops listening and removes the socket file.
    public func stop() {
        source.cancel()
    }

    deinit {
        source.cancel()
    }

    // MARK: - Shared helpers

    static func address(for path: String) throws -> sockaddr_un {
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let bytes = Array(path.utf8)
        let capacity = MemoryLayout.size(ofValue: address.sun_path)
        guard bytes.count < capacity else { throw UnixSocketError.pathTooLong(path) }
        withUnsafeMutableBytes(of: &address.sun_path) { buffer in
            buffer.copyBytes(from: bytes)
            buffer[bytes.count] = 0
        }
        return address
    }

    /// Blocking I/O with a timeout, so a stuck peer can't hang either side.
    static func configure(_ fd: Int32, timeout seconds: Int = 5) {
        var flags = fcntl(fd, F_GETFL)
        flags &= ~O_NONBLOCK
        _ = fcntl(fd, F_SETFL, flags)
        var timeout = timeval(tv_sec: seconds, tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        var noSigPipe: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &noSigPipe, socklen_t(MemoryLayout<Int32>.size))
    }

    /// Reads up to the first newline (excluded), EOF, timeout, or 1 MB.
    static func readLine(from fd: Int32) -> Data {
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while data.count < 1 << 20 {
            let count = read(fd, &buffer, buffer.count)
            guard count > 0 else { break }
            if let newline = buffer[0..<count].firstIndex(of: UInt8(ascii: "\n")) {
                data.append(contentsOf: buffer[0..<newline])
                break
            }
            data.append(contentsOf: buffer[0..<count])
        }
        return data
    }

    static func writeLine(_ data: Data, to fd: Int32) {
        var bytes = [UInt8](data)
        bytes.append(UInt8(ascii: "\n"))
        var offset = 0
        while offset < bytes.count {
            let written = bytes[offset...].withUnsafeBytes { write(fd, $0.baseAddress, $0.count) }
            guard written > 0 else { return }
            offset += written
        }
    }
}

public enum UnixSocketClient {
    /// Sends `message` and waits for the reply.
    public static func send(_ message: Data, to path: String, timeout: Int = 5) throws -> Data {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw UnixSocketError.system("socket", errno: errno) }
        defer { close(fd) }
        UnixSocketServer.configure(fd, timeout: timeout)

        var address = try UnixSocketServer.address(for: path)
        let connected = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard connected == 0 else {
            let code = errno
            if code == ENOENT || code == ECONNREFUSED { throw UnixSocketError.notRunning }
            throw UnixSocketError.system("connect", errno: code)
        }

        UnixSocketServer.writeLine(message, to: fd)
        let reply = UnixSocketServer.readLine(from: fd)
        guard !reply.isEmpty else { throw UnixSocketError.emptyReply }
        return reply
    }
}

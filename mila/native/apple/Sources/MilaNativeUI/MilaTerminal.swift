import Foundation
import Combine
import MilaFFIShim

/// Lifecycle states for a bounded native terminal attachment.
public enum MilaTerminalState: Equatable, Sendable {
    case detached
    case attaching
    case attached
    case reconnecting
    case failed
}

public enum MilaTerminalError: Error, Equatable, Sendable {
    case invalidRequest
    case permissionDenied
    case unavailable
    case outputLimitExceeded
}

/// Host transport supplied by the native application. Terminal bytes stay in this host-owned
/// transport and are never copied into Rust FFI calls.
public protocol MilaTerminalTransport: Sendable {
    func attach(from: UInt64, columns: UInt16, rows: UInt16, readWrite: Bool) async throws
    /// Wait for the next bounded PTY output chunk. `nil` means the remote stream ended.
    /// The default keeps existing host transports source compatible while they are being
    /// upgraded to a real PTY reader.
    func receiveOutput() async throws -> Data?
    func sendInput(_ input: Data) async throws
    func resize(columns: UInt16, rows: UInt16) async throws
    func close() async
}

public extension MilaTerminalTransport {
    func receiveOutput() async throws -> Data? { nil }
}

/// An authenticated host PTY transport. The actual socket/PTY remains owned by the
/// native host, while the Rust session fences every operation to a live authenticated
/// deployment session. Bytes never cross this authorization wrapper.
public final class MilaAuthenticatedTerminalTransport: MilaTerminalTransport, @unchecked Sendable {
    private let authorized: @Sendable () -> Bool
    private let transport: any MilaTerminalTransport

    public init(session: MilaLiveSession, transport: any MilaTerminalTransport) {
        self.authorized = { session.isAuthenticated }
        self.transport = transport
    }

    /// Internal seam for native host tests; production callers must provide a live session.
    init(authorized: @escaping @Sendable () -> Bool, transport: any MilaTerminalTransport) {
        self.authorized = authorized
        self.transport = transport
    }

    public func attach(from: UInt64, columns: UInt16, rows: UInt16, readWrite: Bool) async throws {
        guard authorized() else { throw MilaTerminalError.unavailable }
        guard mila_terminal_attach_validate(from, columns, rows, readWrite ? 1 : 0).rawValue == 0 else {
            throw MilaTerminalError.invalidRequest
        }
        try await transport.attach(from: from, columns: columns, rows: rows, readWrite: readWrite)
    }

    public func sendInput(_ input: Data) async throws {
        guard authorized() else { throw MilaTerminalError.unavailable }
        guard mila_terminal_input_validate(input.count, 1).rawValue == 0 else {
            throw MilaTerminalError.invalidRequest
        }
        try await transport.sendInput(input)
    }

    public func resize(columns: UInt16, rows: UInt16) async throws {
        guard authorized() else { throw MilaTerminalError.unavailable }
        guard mila_terminal_resize_validate(columns, rows, 1).rawValue == 0 else {
            throw MilaTerminalError.invalidRequest
        }
        try await transport.resize(columns: columns, rows: rows)
    }

    public func close() async { await transport.close() }
}

public struct MilaNoopTerminalTransport: MilaTerminalTransport {
    public init() {}
    public func attach(from: UInt64, columns: UInt16, rows: UInt16, readWrite: Bool) async throws {}
    public func receiveOutput() async throws -> Data? { nil }
    public func sendInput(_ input: Data) async throws { _ = input }
    public func resize(columns: UInt16, rows: UInt16) async throws {}
    public func close() async {}
}

/// Main-actor terminal lifecycle model. Rust validates every operation before host transport use.
@MainActor
public final class MilaTerminalController: ObservableObject {
    public static let maximumRenderedOutput = 256 * 1024
    @Published public private(set) var state: MilaTerminalState = .detached
    @Published public private(set) var output = Data()
    @Published public private(set) var columns: UInt16 = 80
    @Published public private(set) var rows: UInt16 = 24
    private let transport: any MilaTerminalTransport
    private var lastAttach: (from: UInt64, columns: UInt16, rows: UInt16, readWrite: Bool)?
    private var receiveTask: Task<Void, Never>?
    private var generation: UInt64 = 0

    public init(transport: any MilaTerminalTransport = MilaNoopTerminalTransport()) {
        self.transport = transport
    }

    public func attach(from: UInt64 = 0, columns: UInt16 = 80, rows: UInt16 = 24, readWrite: Bool = true) async {
        guard validateAttach(from: from, columns: columns, rows: rows, readWrite: readWrite) else {
            state = .failed; return
        }
        generation &+= 1
        state = .attaching
        do {
            try await transport.attach(from: from, columns: columns, rows: rows, readWrite: readWrite)
            self.columns = columns; self.rows = rows
            lastAttach = (from, columns, rows, readWrite)
            state = .attached
            startReceiving()
        } catch { state = .failed }
    }

    public func reconnect() async {
        guard let request = lastAttach else { state = .failed; return }
        state = .reconnecting
        generation &+= 1
        receiveTask?.cancel()
        await transport.close()
        do {
            try await transport.attach(from: request.from, columns: request.columns, rows: request.rows, readWrite: request.readWrite)
            state = .attached
            startReceiving()
        } catch { state = .failed }
    }

    public func sendInput(_ input: Data) async {
        guard state == .attached else { state = .failed; return }
        let permission: UInt8 = 1
        guard mila_terminal_input_validate(input.count, permission).rawValue == 0 else {
            state = .failed; return
        }
        do { try await transport.sendInput(input) } catch { state = .failed }
    }

    public func resize(columns: UInt16, rows: UInt16) async {
        guard state == .attached,
              mila_terminal_resize_validate(columns, rows, 1).rawValue == 0 else { state = .failed; return }
        do { try await transport.resize(columns: columns, rows: rows); self.columns = columns; self.rows = rows }
        catch { state = .failed }
    }

    public func appendOutput(_ bytes: Data) {
        guard bytes.count <= Self.maximumRenderedOutput else { state = .failed; return }
        let available = Self.maximumRenderedOutput - output.count
        output.append(bytes.prefix(available))
    }

    public func close() async {
        receiveTask?.cancel(); receiveTask = nil
        generation &+= 1
        await transport.close(); state = .detached; lastAttach = nil; output.removeAll(keepingCapacity: true)
    }

    private func startReceiving() {
        receiveTask?.cancel()
        let transport = self.transport
        let generation = self.generation
        receiveTask = Task { [weak self] in
            do {
                while !Task.isCancelled {
                    guard let bytes = try await transport.receiveOutput() else { break }
                    guard !bytes.isEmpty else { continue }
                    await MainActor.run { [weak self] in
                        guard let self, self.state == .attached, self.generation == generation else { return }
                        self.appendOutput(bytes)
                    }
                }
            } catch {
                await MainActor.run { [weak self] in
                    guard let self, self.state == .attached, self.generation == generation else { return }
                    self.state = .failed
                }
            }
        }
    }

    private func validateAttach(from: UInt64, columns: UInt16, rows: UInt16, readWrite: Bool) -> Bool {
        mila_terminal_attach_validate(from, columns, rows, readWrite ? 1 : 0).rawValue == 0
    }
}

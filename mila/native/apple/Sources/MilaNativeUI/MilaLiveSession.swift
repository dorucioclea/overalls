import Foundation
import MilaFFIShim

public enum MilaSessionError: Error, Equatable, Sendable {
    case invalidInput
    case transport(Int32)
    case outputTooSmall
    case staleHandle
    case unavailable
}

/// A typed owner for a Rust live session. The handle is closed exactly once.
public final class MilaLiveSession: @unchecked Sendable {
    private let signer: MilaDeviceSigner
    private let host: String
    private let port: UInt16
    private var handle: UInt64
    private let lock = NSLock()

    public init(trust: Data, host: String, port: UInt16, timeoutMilliseconds: UInt32 = 15_000, signer: MilaDeviceSigner) throws {
        guard !trust.isEmpty, !host.isEmpty else { throw MilaSessionError.invalidInput }
        self.signer = signer
        self.host = host
        self.port = port
        var connected: UInt64 = 0
        let status: Int32 = trust.withUnsafeBytes { trustRaw in
            host.utf8CString.withUnsafeBufferPointer { hostBuffer in
                let key = Array(signer.openSSHPublicKey.utf8)
                return key.withUnsafeBufferPointer { keyBuffer in
                    mila_session_connect(trustRaw.bindMemory(to: UInt8.self).baseAddress, trust.count,
                                          hostBuffer.baseAddress, host.utf8.count,
                                          keyBuffer.baseAddress, key.count, port, timeoutMilliseconds,
                                          milaAppleSessionSigner, UInt(bitPattern: Unmanaged.passUnretained(signer).toOpaque()), &connected)
                }
            }
        }
        guard status == 0 else { throw Self.error(status) }
        guard connected != 0 else { throw MilaSessionError.unavailable }
        self.handle = connected
    }

    deinit { close() }

    /// Returns whether the authenticated Rust session is still live.
    /// This is used by host transports to fence terminal operations after sign-out or close.
    public var isAuthenticated: Bool {
        lock.lock(); defer { lock.unlock() }
        return handle != 0
    }

    public func refresh() throws -> Data {
        let current = try validHandle()
        let status = mila_session_read_machines(current, 0)
        guard status == 0 else { throw Self.error(status) }
        return try copyListing(current)
    }

    /// Fetches the bounded browser-approval identity envelope from the live session.
    /// The Rust boundary returns either an authenticated identity or an approval-required
    /// link; callers must decode and validate the envelope before presenting it.
    public func whoami() throws -> Data {
        let current = try validHandle()
        var required = 0
        var status = mila_session_whoami(current, nil, 0, &required)
        guard status == 0 || status == -3, required > 0, required <= 65_536 else { throw Self.error(status) }
        var bytes = [UInt8](repeating: 0, count: required)
        status = mila_session_whoami(current, &bytes, bytes.count, &required)
        guard status == 0 else { throw Self.error(status) }
        return Data(bytes.prefix(required))
    }

    public func sshKeys() throws -> Data {
        let current = try validHandle(); var required = 0
        var status = mila_session_ssh_keys(current, nil, 0, &required)
        guard status == -3, required > 0, required <= 262_144 else { throw Self.error(status) }
        var bytes = [UInt8](repeating: 0, count: required)
        status = mila_session_ssh_keys(current, &bytes, bytes.count, &required)
        guard status == 0 else { throw Self.error(status) }; return Data(bytes.prefix(required))
    }

    public func revokeSSHKey(id: UUID, requestID: UUID) throws {
        let current = try validHandle()
        let key = Array(id.uuidString.lowercased().utf8)
        let request = Array(("porsche-" + requestID.uuidString.lowercased().replacingOccurrences(of: "-", with: "")).utf8)
        let status = key.withUnsafeBufferPointer { k in request.withUnsafeBufferPointer { r in
            mila_session_ssh_key_revoke(current, k.baseAddress, k.count, r.baseAddress, r.count)
        }}
        guard status == 0 else { throw Self.error(status) }
    }

    public func machineAction(machine: UUID, action: String, requestID: UUID) throws {
        let current = try validHandle()
        let machineBytes = Array(machine.uuidString.lowercased().utf8)
        let actionBytes = Array(action.utf8)
        let requestBytes = Array(("porsche-" + requestID.uuidString.lowercased().replacingOccurrences(of: "-", with: "")).utf8)
        let status = machineBytes.withUnsafeBufferPointer { m in actionBytes.withUnsafeBufferPointer { a in requestBytes.withUnsafeBufferPointer { r in
            mila_session_machine_action(current, m.baseAddress, m.count, a.baseAddress, a.count, r.baseAddress, r.count)
        } } }
        guard status == 0 else { throw Self.error(status) }
    }

    public func machineResize(machine: UUID, cpu: UInt32, memory: UInt64, disk: UInt64, requestID: UUID) throws {
        let current = try validHandle()
        guard (1...256).contains(cpu), (256...4_194_304).contains(memory), (1...16_777_216).contains(disk) else { throw MilaFFIError.unavailable }
        let machineBytes = Array(machine.uuidString.lowercased().utf8)
        let requestBytes = Array(("porsche-" + requestID.uuidString.lowercased().replacingOccurrences(of: "-", with: "")).utf8)
        let status = machineBytes.withUnsafeBufferPointer { m in requestBytes.withUnsafeBufferPointer { r in
            mila_session_machine_resize(current, m.baseAddress, m.count, cpu, memory, disk, r.baseAddress, r.count)
        }}
        guard status == 0 else { throw Self.error(status) }
    }

    public func machineCreate(name: String, cpu: UInt32, memory: UInt64, disk: UInt64, requestID: UUID) throws {
        let current = try validHandle()
        let nameBytes = Array(name.utf8)
        let requestBytes = Array(("porsche-" + requestID.uuidString.lowercased().replacingOccurrences(of: "-", with: "")).utf8)
        let status = nameBytes.withUnsafeBufferPointer { n in requestBytes.withUnsafeBufferPointer { r in
            mila_session_machine_create(current, n.baseAddress, n.count, cpu, memory, disk, r.baseAddress, r.count)
        }}
        guard status == 0 else { throw Self.error(status) }
    }

    public func shareMutation(machine: UUID, email: String, role: String?, add: Bool, requestID: UUID) throws {
        let current = try validHandle()
        let machineBytes = Array(machine.uuidString.lowercased().utf8)
        let emailBytes = Array(email.utf8)
        let roleBytes = Array((role ?? "").utf8)
        let requestBytes = Array(("porsche-" + requestID.uuidString.lowercased().replacingOccurrences(of: "-", with: "")).utf8)
        let status = machineBytes.withUnsafeBufferPointer { m in emailBytes.withUnsafeBufferPointer { e in roleBytes.withUnsafeBufferPointer { r in requestBytes.withUnsafeBufferPointer { q in
            mila_session_share_mutation(current, m.baseAddress, m.count, e.baseAddress, e.count, r.baseAddress, r.count, add ? 1 : 0, q.baseAddress, q.count)
        }}}}
        guard status == 0 else { throw Self.error(status) }
    }

    public func threadAction(thread: UUID?, command: String, secondary: String? = nil, input: String? = nil, requestID: UUID? = nil) throws -> Data {
        let current = try validHandle()
        let threadBytes = Array((thread?.uuidString.lowercased() ?? "").utf8)
        let commandBytes = Array(command.utf8)
        let secondaryBytes = Array((secondary ?? "").utf8)
        let inputBytes = Array((input ?? "").utf8)
        let requestBytes = Array((requestID.map { "porsche-" + $0.uuidString.lowercased().replacingOccurrences(of: "-", with: "") } ?? "").utf8)
        func call(_ output: UnsafeMutablePointer<UInt8>?, _ capacity: Int, _ written: UnsafeMutablePointer<Int>) -> Int32 {
            threadBytes.withUnsafeBufferPointer { t in commandBytes.withUnsafeBufferPointer { c in secondaryBytes.withUnsafeBufferPointer { s in inputBytes.withUnsafeBufferPointer { i in requestBytes.withUnsafeBufferPointer { r in
                mila_session_thread_action(current, t.baseAddress, t.count, c.baseAddress, c.count, s.baseAddress, s.count, i.baseAddress, i.count, r.baseAddress, r.count, output, capacity, written)
            }}}}}
        }
        var required = 0
        let first = call(nil, 0, &required)
        guard first == -3, required > 0, required <= 1_048_576 else { throw Self.error(first) }
        var bytes = [UInt8](repeating: 0, count: required)
        let status = bytes.withUnsafeMutableBufferPointer { call($0.baseAddress, $0.count, &required) }
        guard status == 0 else { throw Self.error(status) }
        return Data(bytes.prefix(required))
    }

    /// Fetches the authenticated machine web projection. Rust performs the
    /// HTTPS request and bounds the returned JSON before it crosses the ABI.
    public func webShow(machine: UUID) throws -> Data {
        let current = try validHandle()
        let machineBytes = Array(machine.uuidString.lowercased().utf8)
        var required = 0
        let first = machineBytes.withUnsafeBufferPointer { m in
            mila_session_web_show(current, m.baseAddress, m.count, nil, 0, &required)
        }
        guard first == -3, required > 0, required <= 1_048_576 else { throw Self.error(first) }
        var bytes = [UInt8](repeating: 0, count: required)
        let status = bytes.withUnsafeMutableBufferPointer { output in
            machineBytes.withUnsafeBufferPointer { m in
                mila_session_web_show(current, m.baseAddress, m.count, output.baseAddress, output.count, &required)
            }
        }
        guard status == 0 else { throw Self.error(status) }
        return Data(bytes.prefix(required))
    }

    /// Mutates a machine web endpoint using the server-provided optimistic revision.
    public func webSet(machine: UUID, port: UInt16, publicAccess: Bool, revision: UInt64, requestID: UUID) throws {
        guard port > 0 else { throw MilaSessionError.invalidInput }
        let current = try validHandle()
        let machineBytes = Array(machine.uuidString.lowercased().utf8)
        let requestBytes = Array(("porsche-" + requestID.uuidString.lowercased().replacingOccurrences(of: "-", with: "")).utf8)
        let status = machineBytes.withUnsafeBufferPointer { m in
            requestBytes.withUnsafeBufferPointer { r in
                mila_session_web_set(current, m.baseAddress, m.count, port, publicAccess ? 1 : 0, revision, r.baseAddress, r.count)
            }
        }
        guard status == 0 else { throw Self.error(status) }
    }

    public func readMore() throws -> Data {
        let current = try validHandle()
        let status = mila_session_read_machines(current, 1)
        guard status == 0 else { throw Self.error(status) }
        return try copyListing(current)
    }

    public func close() {
        lock.lock(); defer { lock.unlock() }
        guard handle != 0 else { return }
        _ = mila_session_close(handle)
        handle = 0
    }

    private func validHandle() throws -> UInt64 {
        lock.lock(); defer { lock.unlock() }
        guard handle != 0 else { throw MilaSessionError.staleHandle }
        return handle
    }

    private func copyListing(_ handle: UInt64) throws -> Data {
        var required = 0
        var status = mila_session_listing(handle, nil, 0, &required)
        guard status == 0 || status == -3, required > 0, required <= 1_048_576 else { throw Self.error(status) }
        var bytes = [UInt8](repeating: 0, count: required)
        status = mila_session_listing(handle, &bytes, bytes.count, &required)
        guard status == 0 else { throw Self.error(status) }
        return Data(bytes.prefix(required))
    }

    private static func error(_ status: Int32) -> MilaSessionError {
        switch status { case -3: return .outputTooSmall; case -10: return .staleHandle; case -11, -12, -13, -14: return .transport(status); case -4, -1: return .invalidInput; default: return .transport(status) }
    }
}

private func milaAppleSessionSigner(_ context: UInt, _ message: UnsafePointer<UInt8>?, _ length: Int, _ signature: UnsafeMutablePointer<UInt8>?) -> Int32 {
    guard context != 0, let message, let signature, length > 0, length <= 65_536 else { return -1 }
    do {
        let signer = Unmanaged<MilaDeviceSigner>.fromOpaque(UnsafeRawPointer(bitPattern: context)!).takeUnretainedValue()
        let raw = try signer.sign(message: Data(bytes: message, count: length))
        guard raw.count == 64 else { return -1 }
        raw.copyBytes(to: signature, count: 64)
        return 0
    } catch { return -1 }
}

import Foundation

public struct MilaSSHKey: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let fingerprint: String
    public let algorithm: String
    public let label: String?
    public let isCurrentDevice: Bool

    public init(id: UUID, fingerprint: String, algorithm: String, label: String? = nil, isCurrentDevice: Bool = false) {
        self.id = id; self.fingerprint = fingerprint; self.algorithm = algorithm; self.label = label; self.isCurrentDevice = isCurrentDevice
    }

    /// Reject untrusted projections before they reach the UI or revoke boundary.
    public static func validated(id: UUID, fingerprint: String, algorithm: String, label: String? = nil, isCurrentDevice: Bool = false) -> MilaSSHKey? {
        guard !fingerprint.isEmpty, fingerprint.utf8.count <= 256,
              !algorithm.isEmpty, algorithm.utf8.count <= 128,
              label?.utf8.count ?? 0 <= 256 else { return nil }
        return MilaSSHKey(id: id, fingerprint: fingerprint, algorithm: algorithm, label: label, isCurrentDevice: isCurrentDevice)
    }
}

public enum MilaSSHKeysState: Equatable, Sendable { case signedOut, loading, loaded([MilaSSHKey]), failed }

@MainActor public final class MilaSSHKeysController: ObservableObject {
    @Published public private(set) var state: MilaSSHKeysState = .signedOut
    private let loader: () async throws -> [MilaSSHKey]
    private let revoker: (UUID) async throws -> Void
    private var generation: UInt64 = 0
    private var sessionActive = false

    public init(loader: @escaping () async throws -> [MilaSSHKey], revoker: @escaping (UUID) async throws -> Void) {
        self.loader = loader; self.revoker = revoker
    }

    public func load(signedIn: Bool) async {
        generation &+= 1
        let requestGeneration = generation
        sessionActive = signedIn
        guard signedIn else { state = .signedOut; return }
        state = .loading
        do {
            let keys = try await loader()
            guard sessionActive, requestGeneration == generation else { return }
            state = .loaded(keys)
        } catch {
            guard sessionActive, requestGeneration == generation else { return }
            state = .failed
        }
    }

    public func setSessionActive(_ active: Bool) {
        generation &+= 1
        sessionActive = active
        if !active { state = .signedOut }
    }

    /// @cc [owner:ghuntley,label:security] mila-apple-ssh-revoke
    /// Revocation targets only the selected opaque key identity and refreshes the list after success.
    public func revoke(_ key: MilaSSHKey) async {
        guard sessionActive, case .loaded = state else { return }
        // The signer currently in use cannot be revoked from this session: doing
        // so would strand the authenticated device and differs across platforms.
        guard !key.isCurrentDevice else { return }
        do { try await revoker(key.id); await load(signedIn: true) } catch { state = .failed }
    }
}

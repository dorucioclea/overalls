import Foundation
import Combine

public struct MilaSharePrincipal: Equatable, Sendable {
    public let value: String
    public init(_ raw: String) throws {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (3...256).contains(value.utf8.count), !value.unicodeScalars.contains(where: { $0.value < 0x20 || $0.value == 0x7f }) else {
            throw MilaMachineSharingError.invalidPrincipal
        }
        self.value = value
    }
}

/// Roles accepted by the authenticated sharing protocol. Keeping this closed prevents
/// UI strings from becoming an unvalidated command argument at the FFI boundary.
public enum MilaShareRole: String, CaseIterable, Identifiable, Sendable {
    case viewer, operatorRole = "operator", manager
    public var id: String { rawValue }
}

public enum MilaMachineSharingError: Error, Equatable, Sendable {
    case invalidPrincipal
    case invalidRequestID
    case signedOut
    case noMachine
    case unavailable
}

public enum MilaMachineSharingState: Equatable, Sendable {
    case signedOut
    case idle
    case submitting(machineID: UUID, principal: MilaSharePrincipal, remove: Bool)
    case applied(machineID: UUID, principal: MilaSharePrincipal, remove: Bool)
    case failed(machineID: UUID?, principal: MilaSharePrincipal?, remove: Bool, error: MilaMachineSharingError)
}

@MainActor
public final class MilaMachineSharingController: ObservableObject {
    @Published public private(set) var state: MilaMachineSharingState = .signedOut
    private let adapter: any MilaFFIAdapter
    private var machine: MilaMachinePresentation?
    private var authenticated = false
    private var task: Task<Void, Never>?
    private var generation: UInt64 = 0

    public init(adapter: any MilaFFIAdapter) { self.adapter = adapter }
    deinit { task?.cancel() }

    public func setSession(signedIn: Bool, machine: MilaMachinePresentation?) {
        generation &+= 1
        task?.cancel()
        task = nil
        authenticated = signedIn
        self.machine = signedIn ? machine : nil
        state = signedIn ? (machine == nil ? .idle : .idle) : .signedOut
    }

    public func select(machine: MilaMachinePresentation?) {
        guard authenticated else { return }
        generation &+= 1
        task?.cancel()
        task = nil
        self.machine = machine
        state = .idle
    }

    public func submit(principal raw: String, role: MilaShareRole = .viewer, remove: Bool = false, requestID: UUID = UUID()) {
        guard authenticated else { state = .failed(machineID: machine?.id, principal: nil, remove: remove, error: .signedOut); return }
        guard let machine else { state = .failed(machineID: nil, principal: nil, remove: remove, error: .noMachine); return }
        guard requestID.uuidString != "00000000-0000-0000-0000-000000000000" else { state = .failed(machineID: machine.id, principal: nil, remove: remove, error: .invalidRequestID); return }
        let principal: MilaSharePrincipal
        do { principal = try MilaSharePrincipal(raw) }
        catch { state = .failed(machineID: machine.id, principal: nil, remove: remove, error: .invalidPrincipal); return }
        state = .submitting(machineID: machine.id, principal: principal, remove: remove)
        let requestGeneration = generation
        task = Task { [adapter] in
            do {
                try await adapter.submitShare(principal, role: remove ? nil : role, machine: machine, remove: remove, requestID: requestID)
                guard !Task.isCancelled, requestGeneration == generation, authenticated else { return }
                state = .applied(machineID: machine.id, principal: principal, remove: remove)
            } catch {
                guard !Task.isCancelled, requestGeneration == generation, authenticated else { return }
                state = .failed(machineID: machine.id, principal: principal, remove: remove, error: (error as? MilaMachineSharingError) ?? .unavailable)
            }
        }
    }

    public func reset() { task?.cancel(); task = nil; state = authenticated ? .idle : .signedOut }
}

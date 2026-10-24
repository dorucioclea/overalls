import Foundation
import Combine

public enum MilaMachineMutationState: Equatable, Sendable {
    case idle
    case submitting(requestID: UUID, action: MilaMachineAction)
    case applied(requestID: UUID, action: MilaMachineAction)
    case failed(requestID: UUID, action: MilaMachineAction, error: MilaFFIError)
}

@MainActor
public final class MilaMachineWorkflow: ObservableObject {
    @Published public private(set) var state: MilaMachineMutationState = .idle
    private let adapter: any MilaFFIAdapter
    private var task: Task<Void, Never>?
    private var generation = 0
    private var submittedRequestIDs = Set<UUID>()

    public init(adapter: any MilaFFIAdapter) { self.adapter = adapter }
    deinit { task?.cancel() }

    public func submit(_ action: MilaMachineAction, machine: MilaMachinePresentation, requestID: UUID = UUID()) {
        guard case .idle = state else { return }
        guard submittedRequestIDs.insert(requestID).inserted else {
            state = .failed(requestID: requestID, action: action, error: .actionNotAllowed)
            return
        }
        // Keep malformed presentation/request data out of the native bridge.  These
        // bounds mirror the Rust projection limits and ensure a response can always
        // be represented by the bounded UI state machine.
        let zeroUUID = "00000000-0000-0000-0000-000000000000"
        guard requestID.uuidString.lowercased() != zeroUUID,
              machine.id.uuidString.lowercased() != zeroUUID,
              !machine.machine.name.isEmpty,
              machine.machine.name.utf8.count <= 128,
              machine.machine.name.unicodeScalars.allSatisfy({ $0.value >= 0x20 && $0.value != 0x7f }) else {
            state = .failed(requestID: requestID, action: action, error: .actionNotAllowed)
            return
        }
        guard machine.actions.values.contains(action) else {
            state = .failed(requestID: requestID, action: action, error: .actionNotAllowed)
            return
        }
        state = .submitting(requestID: requestID, action: action)
        let submittedGeneration = generation
        task = Task { [adapter] in
            do {
                try await adapter.submit(action, machine: machine, requestID: requestID)
                guard !Task.isCancelled, submittedGeneration == generation else { return }
                state = .applied(requestID: requestID, action: action)
            } catch let error as MilaFFIError {
                guard !Task.isCancelled, submittedGeneration == generation else { return }
                state = .failed(requestID: requestID, action: action, error: error)
            } catch {
                guard !Task.isCancelled, submittedGeneration == generation else { return }
                state = .failed(requestID: requestID, action: action, error: .unavailable)
            }
        }
    }

    public func reset() { generation &+= 1; task?.cancel(); task = nil; state = .idle }
}

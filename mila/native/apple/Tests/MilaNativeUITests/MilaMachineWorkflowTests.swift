import XCTest
@testable import MilaNativeUI

@MainActor
final class MilaMachineWorkflowTests: XCTestCase {
    private func machine() throws -> MilaMachinePresentation {
        let data = Data(#"{"version":1,"host":"mgmt.example.test","port":null,"saved_at":1,"machines":[{"id":"11111111-1111-1111-1111-111111111111","name":"Test","desired_state":"running","observed_state":"running","pinned":false,"owner":"owner","read":true,"write":true,"manage":false}]}"#.utf8)
        return try LinkedMilaFFIAdapter().projectSnapshot(data, host: "mgmt.example.test").machines[0]
    }

    func testRefusesActionAbsentFromRustPolicy() throws {
        let workflow = MilaMachineWorkflow(adapter: UnavailableMilaFFIAdapter())
        let value = try machine()
        workflow.submit(.delete, machine: value)
        guard case .failed(_, .delete, .actionNotAllowed) = workflow.state else {
            return XCTFail("policy refusal must be represented as a terminal typed state")
        }
    }

    func testAuthenticatedSubmissionHasBoundedFailureStateWhenRuntimeUnavailable() throws {
        let workflow = MilaMachineWorkflow(adapter: UnavailableMilaFFIAdapter())
        let value = try machine()
        workflow.submit(.stop, machine: value)
        guard case .submitting = workflow.state else { return XCTFail("submission starts in submitting state") }
        let expectation = expectation(description: "submission completes")
        Task {
            for _ in 0..<20 {
                if case .failed(_, .stop, .unavailable) = workflow.state { expectation.fulfill(); return }
                try? await Task.sleep(for: .milliseconds(10))
            }
        }
        wait(for: [expectation], timeout: 1)
    }

    func testResetInvalidatesInFlightMutationGeneration() throws {
        let workflow = MilaMachineWorkflow(adapter: UnavailableMilaFFIAdapter())
        workflow.submit(.stop, machine: try machine())
        workflow.reset()
        guard case .idle = workflow.state else { return XCTFail("reset must return to idle") }
    }

    func testRequestIDCannotBeReusedAfterReset() throws {
        let workflow = MilaMachineWorkflow(adapter: UnavailableMilaFFIAdapter())
        let id = UUID()
        let value = try machine()
        workflow.submit(.stop, machine: value, requestID: id)
        workflow.reset()
        workflow.submit(.stop, machine: value, requestID: id)
        guard case .failed(let requestID, .stop, .actionNotAllowed) = workflow.state,
              requestID == id else { return XCTFail("request IDs must be at-most-once") }
    }

    func testZeroRequestIDIsRejectedBeforeBridgeSubmission() throws {
        let workflow = MilaMachineWorkflow(adapter: UnavailableMilaFFIAdapter())
        let zero = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
        workflow.submit(.stop, machine: try machine(), requestID: zero)
        guard case .failed(let requestID, .stop, .actionNotAllowed) = workflow.state,
              requestID == zero else { return XCTFail("zero request IDs must be rejected") }
    }

    func testControlCharacterMachineNameIsRejectedBeforeBridgeSubmission() throws {
        let data = Data(#"{"version":1,"host":"mgmt.example.test","port":null,"saved_at":1,"machines":[{"id":"11111111-1111-1111-1111-111111111111","name":"bad\nname","desired_state":"running","observed_state":"running","pinned":false,"owner":"owner","read":true,"write":true,"manage":false}]}"#.utf8)
        XCTAssertThrowsError(try LinkedMilaFFIAdapter().projectSnapshot(data, host: "mgmt.example.test"))
    }
}

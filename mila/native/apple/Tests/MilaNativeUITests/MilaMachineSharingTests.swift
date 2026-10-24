import XCTest
@testable import MilaNativeUI

@MainActor
final class MilaMachineSharingTests: XCTestCase {
    private func machine() throws -> MilaMachinePresentation {
        let data = Data(#"{"version":1,"host":"mgmt.example.test","port":null,"saved_at":1,"machines":[{"id":"11111111-1111-1111-1111-111111111111","name":"Test","desired_state":"running","observed_state":"running","pinned":false,"owner":"owner","read":true,"write":true,"manage":false}]}"#.utf8)
        return try LinkedMilaFFIAdapter().projectSnapshot(data, host: "mgmt.example.test").machines[0]
    }
    func testRejectsInvalidPrincipalBeforeSubmission() throws {
        let c = MilaMachineSharingController(adapter: UnavailableMilaFFIAdapter())
        c.setSession(signedIn: true, machine: try machine())
        c.submit(principal: "x\n")
        guard case .failed(_, nil, false, .invalidPrincipal) = c.state else { XCTFail("invalid principal must be typed") ; return }
    }
    func testSignedOutIsTypedFailure() throws {
        let c = MilaMachineSharingController(adapter: UnavailableMilaFFIAdapter())
        c.submit(principal: "person@example.test")
        guard case .failed(nil, nil, false, .signedOut) = c.state else { XCTFail("signed out must be rejected") ; return }
    }

    func testRejectsZeroRequestIDBeforeSubmission() throws {
        let c = MilaMachineSharingController(adapter: UnavailableMilaFFIAdapter())
        c.setSession(signedIn: true, machine: try machine())
        c.submit(principal: "person@example.test", requestID: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!)
        guard case .failed(_, nil, false, .invalidRequestID) = c.state else { XCTFail("zero request IDs must be rejected"); return }
    }
}

import XCTest
@testable import MilaNativeUI

final class MilaApprovalTests: XCTestCase {
    func testPendingApprovalIsBoundToHttpsDeploymentHost() throws {
        let data = #"{"version":1,"status":"approval_required","fingerprint":"AA:BB:CC:DD:EE:FF:00:11","approval_url":"https://mila.example/ssh/approve/x"}"#.data(using: .utf8)!
        guard case .pending(let info) = try MilaApprovalDecoder.decode(data, expectedHost: "mila.example") else { return XCTFail() }
        XCTAssertEqual(info.url.host, "mila.example")
        XCTAssertEqual(info.fingerprint, "AA:BB:CC:DD:EE:FF:00:11")
    }

    func testApprovalRefusesHostMismatchAndNonHttps() {
        let mismatch = #"{"version":1,"status":"approval_required","fingerprint":"AABBCCDDEEFF0011","approval_url":"https://evil.example/approve"}"#.data(using: .utf8)!
        XCTAssertThrowsError(try MilaApprovalDecoder.decode(mismatch, expectedHost: "mila.example"))
        let insecure = #"{"version":1,"status":"approval_required","fingerprint":"AABBCCDDEEFF0011","approval_url":"http://mila.example/approve"}"#.data(using: .utf8)!
        XCTAssertThrowsError(try MilaApprovalDecoder.decode(insecure, expectedHost: "mila.example"))
    }

    func testApprovedEnvelopeCompletesApproval() throws {
        let data = #"{"version":1,"status":"approved"}"#.data(using: .utf8)!
        XCTAssertEqual(try MilaApprovalDecoder.decode(data), .approved)
    }
}

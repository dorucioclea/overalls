import XCTest
@testable import MilaNativeUI

final class MilaWebControlsTests: XCTestCase {
    @MainActor func testHTTPSOnlyAndCredentialFreeEndpoint() {
        let controller = MilaWebControlsController()
        XCTAssertTrue(controller.set("https://console.example.test/control"))
        XCTAssertNotNil(controller.endpoint)
        XCTAssertFalse(controller.set("http://console.example.test"))
        XCTAssertNil(controller.endpoint)
        XCTAssertFalse(controller.set("https://user:secret@console.example.test"))
        XCTAssertFalse(controller.set("https://console.example.test/#fragment"))
    }

    @MainActor func testAsyncEndpointCommitRejectsSignedOutSession() throws {
        let controller = MilaWebControlsController()
        let endpoint = try MilaWebEndpoint("https://console.example.test/")
        XCTAssertFalse(controller.openAuthenticated(endpoint, sessionActive: false))
        XCTAssertNil(controller.endpoint)
        XCTAssertEqual(controller.error, .unavailable)
        XCTAssertTrue(controller.openAuthenticated(endpoint, sessionActive: true))
        XCTAssertEqual(controller.endpoint, endpoint)
    }

    @MainActor func testOptimisticRevisionConflictFailsClosed() throws {
        let controller = MilaWebControlsController()
        let endpoint = try MilaWebEndpoint("https://console.example.test/")
        XCTAssertTrue(controller.openAuthenticated(endpoint, sessionActive: true, policyRevision: 4, expectedRevision: 4))
        XCTAssertFalse(controller.openAuthenticated(endpoint, sessionActive: true, policyRevision: 5, expectedRevision: 4))
        XCTAssertNil(controller.endpoint)
        XCTAssertEqual(controller.error, .conflict)
        XCTAssertFalse(controller.openAuthenticated(endpoint, sessionActive: true, policyRevision: 0, expectedRevision: 0))
    }

    func testAuthenticatedProjectionIsMachineBoundAndHTTPSOnly() throws {
        let id = UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!
        let json = "{\"machine_id\":\"\(id.uuidString.lowercased())\",\"label\":\"Console\",\"port\":443,\"visibility\":\"private\",\"policy_revision\":7,\"url\":\"https://console.example.test/\",\"route\":\"overalls://machines/\(id.uuidString.lowercased())/web\"}".data(using: .utf8)!
        let projection = try JSONDecoder().decode(MilaWebEndpointProjection.self, from: json)
        XCTAssertEqual(try projection.endpoint(for: id).url.absoluteString, "https://console.example.test/")
        XCTAssertThrowsError(try projection.endpoint(for: UUID()))
    }
}

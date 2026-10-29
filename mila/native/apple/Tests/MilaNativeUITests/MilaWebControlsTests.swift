import WebKit
import XCTest
@testable import MilaNativeUI

@MainActor private final class PolicyBox { var policy: WKNavigationActionPolicy? }

private final class StubNavigationAction: WKNavigationAction {
    private let stubRequest: URLRequest
    init(_ url: String) { stubRequest = URLRequest(url: URL(string: url)!); super.init() }
    override var request: URLRequest { stubRequest }
}

final class MilaWebControlsTests: XCTestCase {
    @MainActor func testHTTPSOnlyAndCredentialFreeEndpoint() {
        let controller = MilaWebControlsController()
        XCTAssertTrue(controller.set("https://console.example.test/control"))
        XCTAssertNotNil(controller.endpoint)
        XCTAssertFalse(controller.set("http://console.example.test"))
        XCTAssertNil(controller.endpoint)
        XCTAssertFalse(controller.set("https://user:secret@console.example.test"))
        XCTAssertFalse(controller.set("https://console.example.test/#fragment"))
        XCTAssertFalse(controller.set("https://console.example.test:0"))
        XCTAssertFalse(controller.set("https://console.example.test:65536"))
        XCTAssertFalse(controller.set("https://console example.test"))
        XCTAssertFalse(controller.set("https://:443/control"))
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

    @MainActor func testSessionInvalidationClearsPublishedWebState() throws {
        let controller = MilaWebControlsController()
        let endpoint = try MilaWebEndpoint("https://console.example.test/")
        XCTAssertTrue(controller.openAuthenticated(endpoint, sessionActive: true, policyRevision: 3, expectedRevision: 3))
        controller.invalidateSession()
        XCTAssertNil(controller.endpoint)
        XCTAssertEqual(controller.policyRevision, 0)
        XCTAssertNil(controller.error)
    }

    /// Calls the delegate the way WebKit does, through the optional protocol
    /// requirement, so a signature that no longer matches fails here.
    @MainActor func testNavigationGuardIsReachedThroughWebKitProtocol() {
        let delegate: any WKNavigationDelegate = MilaWebNavigationGuard(origin: URL(string: "https://console.example.test:8443/app")!)
        let cases: [(String, WKNavigationActionPolicy)] = [
            ("https://console.example.test:8443/other", .allow),
            ("https://CONSOLE.example.test:8443/", .allow),
            ("http://console.example.test:8443/", .cancel),
            ("https://console.example.test/", .cancel),
            ("https://evil.example.test:8443/", .cancel),
            ("https://user:secret@console.example.test:8443/", .cancel),
        ]
        for (url, expected) in cases {
            let decision = PolicyBox()
            let reached: Void? = delegate.webView?(WKWebView(frame: .zero), decidePolicyFor: StubNavigationAction(url),
                                                   decisionHandler: { decision.policy = $0 })
            XCTAssertNotNil(reached, "WebKit cannot reach the navigation guard")
            XCTAssertEqual(decision.policy, expected, url)
        }
    }
}

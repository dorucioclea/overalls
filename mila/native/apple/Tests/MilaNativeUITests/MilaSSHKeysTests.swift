import XCTest
@testable import MilaNativeUI

@MainActor final class MilaSSHKeysTests: XCTestCase {
    func testValidatedRejectsOversizedUntrustedProjection() {
        XCTAssertNil(MilaSSHKey.validated(id: UUID(), fingerprint: String(repeating: "x", count: 257), algorithm: "ssh-ed25519"))
        XCTAssertNil(MilaSSHKey.validated(id: UUID(), fingerprint: "SHA256:x", algorithm: ""))
        XCTAssertNotNil(MilaSSHKey.validated(id: UUID(), fingerprint: "SHA256:x", algorithm: "ssh-ed25519"))
    }

    func testLoadAndRevokeRefreshesOpaqueKeyIdentity() async {
        let id = UUID(); let key = MilaSSHKey(id: id, fingerprint: "SHA256:test", algorithm: "ssh-ed25519")
        var revoked: [UUID] = []; var loads = 0
        let controller = MilaSSHKeysController(loader: { loads += 1; return loads == 1 ? [key] : [] }, revoker: { revoked.append($0) })
        await controller.load(signedIn: true)
        XCTAssertEqual(controller.state, .loaded([key]))
        await controller.revoke(key)
        XCTAssertEqual(revoked, [id]); XCTAssertEqual(controller.state, .loaded([]))
    }

    func testSignedOutDoesNotLoadOrRevoke() async {
        var loaded = false
        let controller = MilaSSHKeysController(loader: { loaded = true; return [] }, revoker: { _ in XCTFail("must not revoke") })
        await controller.load(signedIn: false)
        XCTAssertEqual(controller.state, .signedOut); XCTAssertFalse(loaded)
    }

    func testCurrentDeviceKeyCannotBeRevoked() async {
        let key = MilaSSHKey(id: UUID(), fingerprint: "SHA256:device", algorithm: "ecdsa-sha2-nistp256", isCurrentDevice: true)
        var revoked = false
        let controller = MilaSSHKeysController(loader: { [key] }, revoker: { _ in revoked = true })
        await controller.load(signedIn: true)
        await controller.revoke(key)
        XCTAssertFalse(revoked)
        XCTAssertEqual(controller.state, .loaded([key]))
    }

    func testLateLoadAfterSignOutDoesNotRestoreKeys() async {
        let key = MilaSSHKey(id: UUID(), fingerprint: "SHA256:late", algorithm: "ssh-ed25519")
        let gate = Gate()
        let controller = MilaSSHKeysController(loader: { await gate.wait(); return [key] }, revoker: { _ in })
        let task = Task { await controller.load(signedIn: true) }
        await gate.release()
        controller.setSessionActive(false)
        await task.value
        XCTAssertEqual(controller.state, .signedOut)
    }

    private actor Gate {
        var released = false
        func release() { released = true }
        func wait() async { while !released { await Task.yield() } }
    }
}

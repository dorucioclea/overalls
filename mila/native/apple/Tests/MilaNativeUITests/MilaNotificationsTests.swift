import XCTest
@testable import MilaNativeUI

@MainActor
final class MilaNotificationsTests: XCTestCase {
    #if canImport(UserNotifications)
    func testAPNsTokenEncodingIsStableAndEmptyTokensAreRejected() {
        XCTAssertEqual(MilaAppleNotificationService.tokenString(from: Data([0x00, 0xab, 0xff])), "00abff")
        XCTAssertNil(MilaAppleNotificationService.tokenString(from: Data()))
    }

    func testNotificationActionsAreBoundedToDocumentedCategories() {
        XCTAssertEqual(MilaAppleNotificationService.boundedActionCategory("machine.open"), "machine.open")
        XCTAssertEqual(MilaAppleNotificationService.boundedActionCategory("thread.reply"), "thread.reply")
        XCTAssertNil(MilaAppleNotificationService.boundedActionCategory("javascript:alert(1)"))
        XCTAssertNil(MilaAppleNotificationService.boundedActionCategory("unknown.open"))
    }
    #endif

    private final class Adapter: MilaFFIAdapter, @unchecked Sendable {
        var calls: [(UInt8, UInt8, String, String, String, String)] = []
        var error: Error?

        func call(_ request: MilaFFIRequest) async throws -> MilaFFIResponse { throw MilaFFIError.unavailable }
        func validatePushRegistration(provider: UInt8, environment: UInt8, token: String, appID: String, deployment: String, endpoint: String) throws {
            calls.append((provider, environment, token, appID, deployment, endpoint))
            if let error { throw error }
        }
    }

    private final class Store: MilaNotificationDeviceStore {
        var values: [MilaNotificationDevice] = []
        func list() -> [MilaNotificationDevice] { values }
        func upsert(_ device: MilaNotificationDevice) -> Bool { values.removeAll { $0.id == device.id }; values.append(device); return true }
        func remove(id: String) -> Bool { let old = values.count; values.removeAll { $0.id == id }; return values.count != old }
    }

    func testStoreRejectsOversizedMetadataAndBoundsProjection() {
        let store = Store()
        XCTAssertFalse(store.upsert(MilaNotificationDevice(id: String(repeating: "x", count: 257), deployment: "mila.example.test", enabled: true)))
        XCTAssertFalse(store.upsert(MilaNotificationDevice(id: "device", deployment: String(repeating: "x", count: 257), enabled: true)))
        for index in 0..<140 { XCTAssertTrue(store.upsert(MilaNotificationDevice(id: "device-\(index)", deployment: "mila.example.test", enabled: true))) }
        XCTAssertLessThanOrEqual(store.list().count, 128)
    }

    func testRegistrationUsesRustBoundaryAndDoesNotRetainTokenInControllerState() {
        let adapter = Adapter()
        let store = Store()
        let controller = MilaNotificationController(adapter: adapter, appID: "com.example.mila", deployment: "mila.example.test", store: store)
        let token = String(repeating: "a", count: 64)
        controller.register(token: token, endpoint: "https://mila.example.test/push", environment: .sandbox)
        XCTAssertEqual(controller.state, .on)
        XCTAssertEqual(adapter.calls.count, 1)
        XCTAssertEqual(adapter.calls[0].0, MilaPushProvider.apple.rawValue)
        XCTAssertEqual(adapter.calls[0].1, MilaPushEnvironment.sandbox.rawValue)
        XCTAssertEqual(controller.devices.count, 1)
        XCTAssertEqual(controller.devices[0].enabled, true)
        controller.disable()
        XCTAssertEqual(controller.state, .off)
        XCTAssertEqual(controller.devices[0].enabled, false)
        XCTAssertTrue(controller.removeDevice(id: "com.example.mila"))
        XCTAssertTrue(controller.devices.isEmpty)
    }

    func testSignedOutSessionHidesDevicesAndRefusesMutations() {
        let adapter = Adapter()
        let store = Store()
        let controller = MilaNotificationController(adapter: adapter, appID: "com.example.mila", deployment: "mila.example.test", store: store)
        controller.register(token: String(repeating: "a", count: 64), endpoint: "https://mila.example.test/push")
        XCTAssertEqual(controller.state, .on)
        controller.setSessionActive(false)
        XCTAssertTrue(controller.devices.isEmpty)
        controller.register(token: String(repeating: "b", count: 64), endpoint: "https://mila.example.test/push")
        XCTAssertEqual(controller.state, .failed)
        XCTAssertFalse(controller.removeDevice(id: "com.example.mila"))
        controller.setSessionActive(true)
        XCTAssertEqual(controller.devices.count, 1)
    }


    func testRegistrationRejectsInvalidTokenAndEndpointBeforeBoundary() {
        let adapter = Adapter()
        let controller = MilaNotificationController(adapter: adapter, appID: "com.example.mila", deployment: "mila.example.test", store: Store())
        controller.register(token: String(repeating: "a", count: 31), endpoint: "https://mila.example.test/push")
        XCTAssertEqual(controller.state, .failed)
        controller.register(token: String(repeating: "a", count: 32), endpoint: "http://mila.example.test/push")
        XCTAssertEqual(controller.state, .failed)
        controller.register(token: String(repeating: "a", count: 32), endpoint: "https://user@mila.example.test/push#fragment")
        XCTAssertEqual(controller.state, .failed)
        XCTAssertTrue(adapter.calls.isEmpty)
        controller.register(token: String(repeating: "a", count: 32), endpoint: "https://bad host.test/push")
        XCTAssertEqual(controller.state, .failed)
        XCTAssertTrue(adapter.calls.isEmpty)
    }

    func testEmptyTokenFailsBeforeCrossingBoundary() {
        let adapter = Adapter()
        let controller = MilaNotificationController(adapter: adapter, appID: "com.example.mila", deployment: "mila.example.test")
        controller.register(token: "", endpoint: "https://mila.example.test/push")
        XCTAssertEqual(controller.state, .failed)
        XCTAssertTrue(adapter.calls.isEmpty)
    }

    func testRustRejectionDoesNotEnableNotifications() {
        let adapter = Adapter()
        adapter.error = MilaFFIError.unavailable
        let controller = MilaNotificationController(adapter: adapter, appID: "com.example.mila", deployment: "mila.example.test")
        controller.register(token: String(repeating: "b", count: 64), endpoint: "https://mila.example.test/push")
        XCTAssertEqual(controller.state, .failed)
    }
}

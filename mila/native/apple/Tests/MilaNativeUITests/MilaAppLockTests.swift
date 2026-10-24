import XCTest
@testable import MilaNativeUI

private struct FakeEvaluator: MilaBiometricEvaluator, Sendable {
    var available: Bool
    var result: Bool
    init(available: Bool = true, result: Bool = true) { self.available = available; self.result = result }
    nonisolated func availability() -> Bool { available }
    nonisolated func authenticate(reason: String) async -> Bool { result }
}

@MainActor
final class MilaAppLockTests: XCTestCase {
    func testDisabledStartsUnlocked() {
        let controller = MilaAppLockController(enabled: false, evaluator: FakeEvaluator())
        XCTAssertEqual(controller.state, .unlocked)
    }

    func testUnavailableAuthenticatorRefusesEnablement() async {
        let suite = "MilaAppLockTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let controller = MilaAppLockController(enabled: false, evaluator: FakeEvaluator(available: false), defaults: defaults)
        await controller.setEnabled(true)
        XCTAssertEqual(controller.state, .unavailable)
        XCTAssertTrue(defaults.bool(forKey: "mila.appLockEnabled"))
        XCTAssertFalse(controller.canEnable)
    }

    func testEnabledAuthenticatesAndUnlocks() async {
        let controller = MilaAppLockController(enabled: true, evaluator: FakeEvaluator())
        XCTAssertEqual(controller.state, .locked)
        await controller.unlock()
        XCTAssertEqual(controller.state, .unlocked)
    }

    func testLockReturnsToLocked() async {
        let controller = MilaAppLockController(evaluator: FakeEvaluator())
        controller.lock()
        XCTAssertEqual(controller.state, .locked)
        await controller.unlock()
        XCTAssertEqual(controller.state, .unlocked)
    }

    func testEnabledPreferenceSurvivesControllerRecreationAndBackgroundLocks() async {
        let suite = "MilaAppLockTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let first = MilaAppLockController(evaluator: FakeEvaluator(), defaults: defaults)
        await first.setEnabled(true)
        XCTAssertTrue(defaults.bool(forKey: "mila.appLockEnabled"))
        XCTAssertEqual(first.state, .unlocked)
        first.sceneDidEnterBackground()
        XCTAssertEqual(first.state, .locked)
        let recreated = MilaAppLockController(evaluator: FakeEvaluator(), defaults: defaults)
        XCTAssertEqual(recreated.state, .locked)
        await recreated.sceneWillEnterForeground()
        XCTAssertEqual(recreated.state, .unlocked)
    }

    func testDisablingLockClearsDurablePreference() async {
        let suite = "MilaAppLockTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let controller = MilaAppLockController(evaluator: FakeEvaluator(), defaults: defaults)
        await controller.setEnabled(true)
        await controller.setEnabled(false)
        XCTAssertFalse(defaults.bool(forKey: "mila.appLockEnabled"))
        XCTAssertEqual(controller.state, .unlocked)
    }
}

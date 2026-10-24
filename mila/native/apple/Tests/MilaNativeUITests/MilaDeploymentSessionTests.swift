import XCTest
@testable import MilaNativeUI

final class MilaDeploymentSessionTests: XCTestCase {
    private func deployment(_ host: String = "mila.example") -> MilaDeployment { MilaDeployment(id: UUID(), host: host, port: 22, trust: Data([1, 2, 3])) }
    func testSelectionAndReconnectUseDurableDeployment() {
        let suite = "mila.session.\(UUID().uuidString)"; let defaults = UserDefaults(suiteName: suite)!; defer { defaults.removePersistentDomain(forName: suite) }
        let store = MilaDeploymentStore(defaults: defaults); let value = deployment(); XCTAssertTrue(store.upsert(value));
        let coordinator = MilaDeploymentSessionCoordinator(store: store, defaults: defaults) { _ in UnavailableMilaFFIAdapter() }
        XCTAssertTrue(coordinator.select(value)); XCTAssertEqual(coordinator.selectedDeployment?.id, value.id); XCTAssertTrue(coordinator.reconnect());
        if case .signedIn(let id, let generation) = coordinator.state { XCTAssertEqual(id, value.id); XCTAssertGreaterThan(generation, 0); XCTAssertNotNil(coordinator.adapter(for: generation)) } else { XCTFail("expected signed in") }
    }
    func testSignOutFencesOldGeneration() {
        let suite = "mila.session.\(UUID().uuidString)"; let defaults = UserDefaults(suiteName: suite)!; defer { defaults.removePersistentDomain(forName: suite) }
        let store = MilaDeploymentStore(defaults: defaults); let value = deployment(); XCTAssertTrue(store.upsert(value));
        let coordinator = MilaDeploymentSessionCoordinator(store: store, defaults: defaults) { _ in UnavailableMilaFFIAdapter() }; XCTAssertTrue(coordinator.signIn(value)); let generation = coordinator.currentGeneration(); coordinator.signOut(); XCTAssertNil(coordinator.adapter(for: generation)); XCTAssertEqual(coordinator.state, .signedOut)
    }
    func testFailedReconnectFencesPriorAuthenticatedGeneration() {
        let suite = "mila.session.\(UUID().uuidString)"; let defaults = UserDefaults(suiteName: suite)!; defer { defaults.removePersistentDomain(forName: suite) }
        let store = MilaDeploymentStore(defaults: defaults); let value = deployment(); XCTAssertTrue(store.upsert(value))
        var attempts = 0
        let coordinator = MilaDeploymentSessionCoordinator(store: store, defaults: defaults) { _ in
            attempts += 1
            if attempts == 1 { return UnavailableMilaFFIAdapter() }
            throw NSError(domain: "test", code: 1)
        }
        XCTAssertTrue(coordinator.signIn(value)); let oldGeneration = coordinator.currentGeneration()
        XCTAssertFalse(coordinator.reconnect())
        XCTAssertNil(coordinator.adapter(for: oldGeneration))
        if case .failed(let id, _) = coordinator.state { XCTAssertEqual(id, value.id) } else { XCTFail("expected failed reconnect") }
    }

    func testForgettingSelectedDeploymentSignsOutAndClearsSelection() {
        let suite = "mila.session.\(UUID().uuidString)"; let defaults = UserDefaults(suiteName: suite)!; defer { defaults.removePersistentDomain(forName: suite) }
        let store = MilaDeploymentStore(defaults: defaults); let value = deployment(); XCTAssertTrue(store.upsert(value))
        let coordinator = MilaDeploymentSessionCoordinator(store: store, defaults: defaults) { _ in UnavailableMilaFFIAdapter() }
        XCTAssertTrue(coordinator.signIn(value)); let generation = coordinator.currentGeneration()
        XCTAssertTrue(coordinator.remove(value.id)); XCTAssertNil(coordinator.selectedDeployment); XCTAssertEqual(coordinator.state, .signedOut); XCTAssertNil(coordinator.adapter(for: generation)); XCTAssertTrue(store.list().isEmpty)
    }
}

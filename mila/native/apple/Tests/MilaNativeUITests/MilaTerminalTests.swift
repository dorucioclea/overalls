import XCTest
@testable import MilaNativeUI

@MainActor
final class MilaTerminalTests: XCTestCase {
    func testAttachRequestIDIsAtMostOnce() async {
        let controller = MilaTerminalController()
        let id = UUID()
        await controller.attach(requestID: id)
        XCTAssertEqual(controller.state, .attached)
        await controller.attach(requestID: id)
        XCTAssertEqual(controller.state, .failed)
    }
}

import XCTest
@testable import MilaNativeUI

@MainActor
final class MilaTerminalTests: XCTestCase {
    private struct EOFTransport: MilaTerminalTransport {
        func attach(from: UInt64, columns: UInt16, rows: UInt16, readWrite: Bool) async throws {}
        func receiveOutput() async throws -> Data? { nil }
        func sendInput(_ input: Data) async throws {}
        func resize(columns: UInt16, rows: UInt16) async throws {}
        func close() async {}
    }

    func testAttachRequestIDIsAtMostOnce() async {
        let controller = MilaTerminalController()
        let id = UUID()
        await controller.attach(requestID: id)
        XCTAssertEqual(controller.state, .attached)
        await controller.attach(requestID: id)
        XCTAssertEqual(controller.state, .failed)
    }

    func testReconnectClearsPreviousGenerationOutput() async {
        let controller = MilaTerminalController(transport: EOFTransport())
        await controller.attach()
        controller.appendOutput(Data("stale".utf8))
        XCTAssertFalse(controller.output.isEmpty)
        await controller.reconnect()
        XCTAssertTrue(controller.output.isEmpty)
    }

    func testCleanEOFMarksTransportFailed() async {
        let controller = MilaTerminalController(transport: EOFTransport())
        await controller.attach()
        for _ in 0..<20 where controller.state == .attached {
            await Task.yield()
        }
        XCTAssertEqual(controller.state, .failed)
    }

    func testOutputArrivingAfterCloseIsIgnored() async {
        let controller = MilaTerminalController(transport: EOFTransport())
        await controller.attach()
        await controller.close()
        controller.appendOutput(Data("late".utf8))
        XCTAssertTrue(controller.output.isEmpty)
    }
}

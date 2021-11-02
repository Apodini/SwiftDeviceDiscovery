import XCTest
import class Foundation.Bundle
@testable import DeviceDiscovery

final class DeviceDiscoveryTests: XCTestCase {
    func testEmptyDiscovery() throws {
        let discovery = DeviceDiscovery(DeviceIdentifier("_dummy._tcp."))
        discovery.configuration = [
            .username: "ubuntu",
            .password: "test1234",
            .runPostActions: false
        ]
        let results = try discovery.run().wait()
        XCTAssert(results.isEmpty)
    }
}

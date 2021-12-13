//
// This source file is part of the Apodini open source project
//
// SPDX-FileCopyrightText: 2019-2021 Paul Schmiedmayer and the Apodini project authors (see CONTRIBUTORS.md) <paul.schmiedmayer@tum.de>
//
// SPDX-License-Identifier: MIT
//

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

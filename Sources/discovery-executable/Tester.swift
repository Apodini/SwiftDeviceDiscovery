//
// This source file is part of the Apodini open source project
//
// SPDX-FileCopyrightText: 2019-2021 Paul Schmiedmayer and the Apodini project authors (see CONTRIBUTORS.md) <paul.schmiedmayer@tum.de>
//
// SPDX-License-Identifier: MIT
//

import Foundation
import DeviceDiscovery
import NIO
import Logging

@main
enum Tester {
    static func main() throws {
        //Do something
        let discovery = DeviceDiscovery(DeviceIdentifier("_workstation._tcp."))
        discovery.configuration = [
            .username: "ubuntu",
            .password: "test1234",
            .runPostActions: true
        ]
        try discovery.run()
    }
}

//
//  Tester.swift
//  
//
//  Created by Felix Desiderato on 11/07/2021.
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
        try discovery.run(1)
    }
}

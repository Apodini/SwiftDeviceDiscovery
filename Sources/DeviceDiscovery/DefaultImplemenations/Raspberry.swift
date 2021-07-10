//
//  File.swift
//  
//
//  Created by Felix Desiderato on 10/07/2021.
//

import Foundation
import NIOLIFX
import NIO

struct Raspberry: Device {
    static var identifier: DeviceIdentifier = DeviceIdentifier("_workstation._tcp.")
    
    var service: NetService?
    
    var configuration: [ConfigurationOption : Any] {
        [
            .username: "pi",
            .password: "rasp",
            .runPostActions: true
        ]
    }
}

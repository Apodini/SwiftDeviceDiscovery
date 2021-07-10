//
//  File.swift
//  
//
//  Created by Felix Desiderato on 10/07/2021.
//

import Foundation
import NIOLIFX
import NIO

public struct Raspberry: Device {
    public static var identifier: DeviceIdentifier = DeviceIdentifier("_workstation._tcp.")
    
    public var service: NetService?
    
    public var configuration: [ConfigurationOption : Any] {
        [
            .username: "pi",
            .password: "rasp",
            .runPostActions: true
        ]
    }
    
    public init() {
        
    }
}

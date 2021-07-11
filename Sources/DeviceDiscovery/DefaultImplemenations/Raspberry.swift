//
//  File.swift
//  
//
//  Created by Felix Desiderato on 10/07/2021.
//

import Foundation
import NIOLIFX
import NIO

/// A default implementation of a `Device`. Used for dummy and testing purposes.
public struct Raspberry: Device {
    public mutating func configure() {
        print("TODO")
    }
    
    public static var identifier: DeviceIdentifier = DeviceIdentifier("_workstation._tcp.")
    
    public var service: NetService
    
    public var configuration: [ConfigurationOption : Any] {
        [
            .username: "pi",
            .password: "rasp",
            .runPostActions: true
        ]
    }
    
    public init(_ service: NetService) {
        self.service = service
    }
}

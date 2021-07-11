//
//  PostDiscoveryAction.swift
//  
//
//  Created by Felix Desiderato on 10/07/2021.
//

import Foundation
import NIO
import NIOLIFX

/// An identifier object that is used to identify a `PostDiscoveryAction`
public struct ActionIdentifier: RawRepresentable, Hashable, Equatable, Codable {
    public let rawValue: String
    
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
    
    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}

/// A protocol that can be implemented to specify a `PostDiscoveryAction`. These will be executed after the discovery phase and
/// allow to for custom actions on the found device. Typically it is used to search for end devices that are connected to the found device.
public protocol PostDiscoveryAction {
    /// The identifier object of a `PostDiscoveryAction`.
    static var identifier: ActionIdentifier { get }
    /// Default empty initializer.
    init()
    /// Performs the `PostDiscoveryAction`.
    /// - Parameter device: The `Device` object the action is performed on
    /// - Parameter eventLoopGroup: A `EventLoopGroup`.
    /// - Returns Int: numberOfFoundDevices.
    func run<Device>(_ device: Device, on eventLoopGroup: EventLoopGroup) throws -> Int?
}

/// A Default implementation of a `PostDiscoveryAction`. It looks for connected LIFX smart lamps using NIOLIFX.
public struct LIFXDeviceDiscoveryAction: PostDiscoveryAction {
    public static var identifier: ActionIdentifier {
        ActionIdentifier("LIFX")
    }
    
    var networkDevice: NIONetworkDevice? {
        let networkInterfaces = try! System.enumerateDevices()
        for interface in networkInterfaces {
            if case .v4 = interface.address, interface.name == "en0" {
                return interface
            }
        }
        return nil
    }
    
    public func run<Device>(_ device: Device, on eventLoopGroup: EventLoopGroup) throws -> Int? {
        guard let netDevice = networkDevice else { return nil }
        
        let manager = try LIFXDeviceManager(using: netDevice, on: eventLoopGroup, logLevel: .info)
        try manager.discoverDevices().wait()
        return manager.devices.count
    }
    
    public init() {}
}

public struct DiscoveryResult {
    let device: Device
    let foundEndDevices: [ActionIdentifier: Int]
}

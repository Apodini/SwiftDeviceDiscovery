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

extension ActionIdentifier: CustomStringConvertible {
    public var description: String {
        rawValue
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
    func run(_ device: Device, on eventLoopGroup: EventLoopGroup, client: SSHClient?) throws -> EventLoopFuture<Int>
}

public struct DiscoveryResult {
    public let device: Device
    public let foundEndDevices: [ActionIdentifier: Int]
}

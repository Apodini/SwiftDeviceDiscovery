//
//  PostDiscoveryAction.swift
//  
//
//  Created by Felix Desiderato on 10/07/2021.
//

import Foundation
import NIO

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
    /// - Parameter client: An unboot `SSHClient` instance. 
    /// - Returns Int: numberOfFoundDevices.
    func run(_ device: Device, on eventLoopGroup: EventLoopGroup, client: SSHClient?) throws -> EventLoopFuture<Int>
}

/// Contains the final results of the discovery. Each result consists of the found `Device` and a dictionary mapping the `ActionIdentifier` of the
/// `PostDiscoveryAction`s that were run for this discovery to the number of the found devices for that identifier.
public struct DiscoveryResult {
    /// The device the current discovery instance was looking for
    public let device: Device
    /// All `PostDiscoveryAction`s that ran in this instance and the number of devices that were found under their identifier.
    public let foundEndDevices: [ActionIdentifier: Int]
}

extension DiscoveryResult: Equatable {
    public static func == (lhs: DiscoveryResult, rhs: DiscoveryResult) -> Bool {
        lhs.device.identifier == rhs.device.identifier &&
        lhs.foundEndDevices == rhs.foundEndDevices
    }
}

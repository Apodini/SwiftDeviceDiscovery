//
//  Device.swift
//  
//
//  Created by Felix Desiderato on 10/07/2021.
//
import Foundation
import NIO
import Network

/// An identifier object that is used to identify a `Device` object. When set for a `Device`, make sure it matches the type of the published service
/// you are looking for in the network. For example: When looking for raspberry pis, that are using avahi to pushlish their service, set the identifier of a
/// corresponding `Device` object to `_workstation._tcp.` to be able to discover them.
public struct DeviceIdentifier: RawRepresentable, Hashable, Equatable, Codable {
    public static var emptyIdentifier: DeviceIdentifier {
        DeviceIdentifier("")
    }
    
    public let rawValue: String
    
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
    
    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}

// TODO: Might move this to a struct
/// A generic protocol specifying the properties of a `Device`.
/// A Device can be passed as generic parameter to an `DeviceDiscovery`, telling it to look for that device.
public protocol Device: CustomStringConvertible {
    /// The identifer of the device. It has to match the type of the published service. See `DeviceIdentifier` for more infos.
    static var identifier: DeviceIdentifier { get }
    /// The `NetService` that has been found in the network corresponding to the specified `identifier`.
    var service: NetService { get }
    /// An `Int64` object of the macAddress of the found service.
    var macAddress: Int64? { get }
    /// An `String` representation of the ipv4 address of the service.
    var ipv4Address: String? { get }
    /// An `String` representation of the ipv6 address of the service.
    var ipv6Address: String? { get }
    /// The hostname of the service.
    var hostname: String? { get }
    /// Initializes a new device with the given `NetService` and `DeviceIdentifier`
    init(_ service: NetService, identifier: DeviceIdentifier)
}

public extension Device {
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        Self.identifier == Self.identifier
    }
    
    var macAddress: Int64? {
        service.macAddress()
    }
    
    var ipv4Address: String? {
        guard let hostname = self.hostname else {
            return nil
        }
        return IPAddressResolver(hostname).ipv4Address
    }
    
    var ipv6Address: String? {
        guard let hostname = self.hostname else {
            return nil
        }
        return IPAddressResolver(hostname).ipv6Address
    }
    
    var hostname: String? {
        service.hostname()
    }

    var description: String {
        """
        identifier: \(Self.identifier.rawValue),
        hostname: \(String(describing: hostname)),
        ipAddress: \(String(describing: ipv4Address)),
        macAddress: \(String(describing: macAddress)),
        service: \(service)
        """
    }
}

extension NetService {
    func hostname() -> String {
        name.components(separatedBy: .whitespaces)[0]
    }
    
    func macAddress() -> Int64? {
        let address = name.components(separatedBy: .whitespaces)[1]
            .replacingOccurrences(of: ["[", "]", ":"], with: "")
        return Int64(address, radix: 16)
    }
}

extension String {
    func replacingOccurrences(of occurrences: [String], with: String) -> String {
        var result = self
        for occurrence in occurrences {
            result = result.replacingOccurrences(of: occurrence, with: with)
        }
        return result
    }
}

/// A type agnostic implementation of `Device` that is used in `DeviceDiscovery`
public struct AnyDevice: Device {
    public static var identifier: DeviceIdentifier = .emptyIdentifier
    
    public var service: NetService

    public init(_ service: NetService, identifier: DeviceIdentifier) {
        self.service = service
        Self.identifier = identifier
    }
}

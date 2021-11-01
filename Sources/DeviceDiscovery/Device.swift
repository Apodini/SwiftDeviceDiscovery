//
//  Device.swift
//  
//
//  Created by Felix Desiderato on 10/07/2021.
//
import Foundation
import NIO
#if os(Linux)
import NetService
#endif

/// An identifier object that is used to identify a `Device` object. When set for a `Device`, make sure it matches the type of the published service
/// you are looking for in the network. For example: When looking for raspberry pis, that are using avahi to publish their service, set the identifier of a
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

extension NetService {
    func hostname() -> String {
        name.components(separatedBy: .whitespaces)[0]
    }
    
    func macAddress() -> Int64 {
        let address = name.components(separatedBy: .whitespaces)[1]
            .replacingOccurrences(of: ["[", "]", ":"], with: "")
        return Int64(address, radix: 16) ?? -1
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
public struct Device: Equatable {
    public static var identifier: DeviceIdentifier = .emptyIdentifier
    
    public let password: String
    public let username: String
    
    public let ipv4Address: String?
    public let hostname: String
    public let macAddress: Int64
    
    internal let service: NetService
    
    public var description: String {
        """
        identifier: \(Self.identifier.rawValue),
        hostname: \(hostname),
        ipAddress: \(ipv4Address ?? ""),
        macAddress: \(macAddress)
        """
    }
    
    public var identifier: DeviceIdentifier {
        Self.identifier
    }

    public init(
        _ service: NetService,
        identifier: DeviceIdentifier,
        username: String?,
        password: String?
    ) {
        self.service = service
        Self.identifier = identifier
        self.username = username ?? ""
        self.password = password ?? ""
        self.hostname = service.hostname()
        self.macAddress = service.macAddress()
        
        self.ipv4Address = IPAddressResolver.resolveIPAdress(hostname, domain: service.domain)
    }
    
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.identifier == rhs.identifier
    }
}

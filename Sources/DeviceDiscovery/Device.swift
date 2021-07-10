//
//  File.swift
//  
//
//  Created by Felix Desiderato on 10/07/2021.
//
import Foundation
import NIO
import Network

public struct DeviceIdentifier: RawRepresentable, Hashable, Equatable, Codable {
    public let rawValue: String
    
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
    
    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}

protocol Device: CustomStringConvertible {
    static var identifier: DeviceIdentifier { get }
    var configuration: [ConfigurationOption: Any] { get }
    
    var service: NetService? { get set }
    var runPostActions: ((Self, EventLoopGroup) -> Void)? { get }
    
    var macAddress: Int64? { get }
    var ipAddress: IPAddressResolver? { get }
    var hostname: String? { get }
    
    init()
    
    static func convert(from service: NetService) -> Self
}

extension Device {
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        Self.identifier == Self.identifier
    }
    
    public var macAddress: Int64? {
        service?.macAddress()
    }
    
    public var ipAddress: IPAddressResolver? {
        guard let hostname = self.hostname else {
            return nil
        }
        return IPAddressResolver(hostname)
    }
    
    public var hostname: String? {
        service?.hostname()
    }
    
    var configuration: [ConfigurationOption: Any] {
        [.runPostActions: true]
    }
    
    public var runPostActions: ((Self, EventLoopGroup) -> Void)? {
        nil
    }
    
    static func convert(from service: NetService) -> Self {
        var me = Self.init()
        me.service = service
        return me
    }
    
    var description: String {
        """
        type: \(Self.self),
        identifier: \(Self.identifier.rawValue),
        hostname: \(String(describing: hostname)),
        ipAddress: \(String(describing: ipAddress?.ipv4Address)),
        macAddress: \(String(describing: macAddress)),
        service: \(service),
        configuration: \(configuration)
        """
    }
}

extension NetService {
    func convert<T: Device>(to instance: T.Type) -> T {
        instance.convert(from: self)
    }
    
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

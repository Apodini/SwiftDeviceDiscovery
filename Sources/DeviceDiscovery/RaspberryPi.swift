//
//  RaspberryPi.swift
//  DeviceDiscovery
//
//  Created by Felix Desiderato on 31.05.21.
//

import Foundation

class RaspberryPi: NSObject, DiscoverableObject, SSHable {
    var macAddress: Int64?
    
    var id: UUID = UUID()
    
    var username: String = "pi"
    
    var password: String = "rasp"

    var ipAddress: String?
    
    var hostname: String?
    
    init(from service: NetService) {
        self.id = UUID()
        self.macAddress = service.macAddress()
        self.ipAddress = IPAddressResolver(service.hostname()).ipv4Address
        self.hostname = service.hostname()
    }
    
    static func ==(lhs: RaspberryPi, rhs: RaspberryPi) -> Bool {
        guard let lhsAddress = lhs.macAddress, let rhsAddress = rhs.macAddress else { return false }
        return lhsAddress == rhsAddress
    }
}

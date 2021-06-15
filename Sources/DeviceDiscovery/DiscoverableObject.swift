//
//  DiscoverableObject.swift
//  DeviceDiscovery
//
//  Created by Felix Desiderato on 31.05.21.
//

import Foundation

protocol DiscoverableObject {
    var id: UUID { get }
    var ipAddress: String? { get }
    var hostname: String? { get }
    var macAddress: Int64? { get }
}

extension DiscoverableObject where Self: SSHable {
    func sshableHostname() -> String {
        guard let hostname = hostname else { fatalError("Discoverable Object has no hostname") }
        return String(format: "%@@%@.%@", username, hostname, "local")
    }
}

extension Array where Element: DiscoverableObject & SSHable {
    func findObjectByMacAddress(_ address: Int64) -> DiscoverableObject? {
        first(where: { object in
            object.macAddress == address
        })
    }
}

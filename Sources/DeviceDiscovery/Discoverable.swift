//
//  Discoverable.swift
//  DeviceDiscovery
//
//  Created by Felix Desiderato on 31.05.21.
//

import Foundation

protocol Discoverable {
    var remoteDirectoryPath: String { get }
    var pathToDeployableSystem: String { get }
    
    mutating func execute(_ timeout: TimeInterval) throws
    mutating func shutdown() throws -> Int64
}

extension Discoverable {
    var remoteDirectoryPath: String {
        "/usr/deployment/"
    }
    
    var pathToDeployableSystem: String {
        FileManager.default.currentDirectoryPath
    }
}

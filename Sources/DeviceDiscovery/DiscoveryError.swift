//
//  DiscoveryError.swift
//  DiscoveryError
//
//  Created by Felix Desiderato on 14/08/2021.
//

import Foundation

public struct DiscoveryError: Swift.Error {
    public let description: String
    
    public init(_ description: String) {
        self.description = description
    }
}

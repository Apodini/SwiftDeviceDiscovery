//
//  Domain.swift
//  
//
//  Created by Felix Desiderato on 08/07/2021.
//

import Foundation

/// Used to set the domain in which the `DeviceDiscovery` is looking for devices.
public enum Domain {
    /// The local domain.
    case local
    /// A custom domain.
    case custom(String)
    
    /// Returns a string representation of the domain.
    var value: String {
        switch self {
        case .local:
            return "local."
        case .custom(let dom):
            return dom
        }
    }
}

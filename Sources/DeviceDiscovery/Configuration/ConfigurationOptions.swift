//
//  File.swift
//  
//
//  Created by Felix Desiderato on 08/07/2021.
//

import Foundation
import Network

public struct ConfigurationOption: Hashable {
    static let username = ConfigurationOption("key_username")
    static let password = ConfigurationOption("key_password")
    static let runPostActions = ConfigurationOption("key_postActions")
    
    var value: String
    
    init(_ value: String) {
        self.value = value
    }
}

extension Dictionary where Key == ConfigurationOption {
    func typedValue<T: Any>(for key: ConfigurationOption, to: T.Type) -> T? {
        if let value = self[key] as? T {
            return value
        }
        return nil
    }
}

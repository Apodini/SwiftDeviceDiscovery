//
//  ConfigurationOption.swift
//  
//
//  Created by Felix Desiderato on 08/07/2021.
//

import Foundation
import Network

/// A `ConfigurationOption` encapsulates a `String` value and is used as a key in a `Device` configuration property.
public struct ConfigurationOption: Hashable {
    /// A default key specifying the username for a possible ssh injection.
    public static let username = ConfigurationOption("key_username")
    /// A default key specifying the password for a possible ssh injection.
    public static let password = ConfigurationOption("key_password")
    /// A default key specifying if the `DeviceDiscovery` should perform post discovery actions on this device.
    public static let runPostActions = ConfigurationOption("key_postActions")
    
    var value: String
    
    public init(_ value: String) {
        self.value = value
    }
}

public extension Dictionary where Key == ConfigurationOption, Value == Any {
    func typedValue<T: Any>(for key: ConfigurationOption, to: T.Type) -> T? {
        if let value = self[key] as? T {
            return value
        }
        return nil
    }
    
    /// The default configuration for any device discovery. On default, `.runPostActions` is set to true.
    static var defaultConfiguration: Self<ConfigurationOption, Any> {
        [
            .runPostActions: true
        ]
    }
}

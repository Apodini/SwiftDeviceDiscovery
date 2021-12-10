//
// This source file is part of the Apodini open source project
//
// SPDX-FileCopyrightText: 2019-2021 Paul Schmiedmayer and the Apodini project authors (see CONTRIBUTORS.md) <paul.schmiedmayer@tum.de>
//
// SPDX-License-Identifier: MIT
//

import Foundation

/// A `ConfigurationProperty` encapsulates a `String` value and is used as a key in a `Device` configuration property.
public struct ConfigurationProperty: Hashable {
    /// A default key specifying the username for a possible ssh injection. If no value is set for this key, it defaults to an empty string.
    public static let username = ConfigurationProperty("key_username")
    /// A default key specifying the password for a possible ssh injection. If no value is set for this key, it defaults to an empty string.
    public static let password = ConfigurationProperty("key_password")
    /// A default key specifying if the `DeviceDiscovery` should perform post discovery actions on this device.
    public static let runPostActions = ConfigurationProperty("key_postActions")
    
    var value: String
    
    public init(_ value: String) {
        self.value = value
    }
}

extension Dictionary where Key == ConfigurationProperty, Value == Any {
    func typedValue<T: Any>(for key: ConfigurationProperty, to: T.Type) -> T? {
        if let value = self[key] as? T {
            return value
        }
        return nil
    }
    
    /// The default configuration for any device discovery. On default, `.runPostActions` is set to true.
    static var defaultConfiguration: [ConfigurationProperty: Any] {
        [
            .runPostActions: true
        ]
    }
}

/// A local storage for all configuration properties that are used for the device discovery.
public struct ConfigurationStorage: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (ConfigurationProperty, Any)...) {
        self.init(from: [ConfigurationProperty: Any](uniqueKeysWithValues: elements))
    }
    /// Key alias of `ExpressibleByDictionaryLiteral`
    public typealias Key = ConfigurationProperty
    /// Value alias of `ExpressibleByDictionaryLiteral`
    public typealias Value = Any
    /// The singleton of the `ConfigurationStorage`
    internal static var shared = ConfigurationStorage()
    /// The internal storage of the saved values
    internal var storage: [ConfigurationProperty: Any] = .defaultConfiguration

    private init() { }
    
    /// Accesses the environment value associated with a custom key.
    public subscript(key: ConfigurationProperty) -> Any? {
        get {
            storage[key]
        }
        set {
            storage[key] = newValue
        }
    }
    /// Returns the typed value of a given key
    public func typedValue<T>(for key: ConfigurationProperty, to: T.Type) -> T? {
        storage[key] as? T
    }
    /// Allows the initialization of the storage from a directory
    public init(from config: [ConfigurationProperty: Any]) {
        self.storage = config
        Self.shared.storage = config
    }
}

/// A property wrapper of a configuration  that allows access to any configuration value from PostActions.
@propertyWrapper
public struct Configuration<Value> {
    /// The wrapped value of the Configuration
    public var wrappedValue: Value {
        if let value = ConfigurationStorage.shared.typedValue(for: key, to: Value.self) {
            return value
        }
        fatalError("Configuration: No value found for key \(key)")
    }
    private var key: ConfigurationProperty
    
    /// Initializes a Configuration with a `ConfigurationProperty`
    public init(_ key: ConfigurationProperty) {
        self.key = key
    }
}

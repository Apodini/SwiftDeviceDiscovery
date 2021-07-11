//
//  DeviceDiscovery.swift
//  
//
//  Created by Felix Desiderato on 08/07/2021.
//

import Foundation
import Network
import Logging
import NIOLIFX
import NIO

/// Responsible for running a discovery in the given domain for the specified `Device.Type`.
/// The discovery can be configured using the `configuration` property of the device object.
public class DeviceDiscovery: NSObject, NetServiceBrowserDelegate, NetServiceDelegate {
    /// A public typealias for the configuration dictionary.
    public typealias Configration = [ConfigurationOption: Any]
    typealias PerformedAction = [ActionIdentifier: Int]
    
    private var identifier: DeviceIdentifier
    private var domain: Domain
    private var eventLoopGroup: EventLoopGroup
    
    private let browser = NetServiceBrowser()
    private let logger = Logger(label: "device.discovery: discovery")
    
    private var devices: [AnyDevice]
    
    /// The `PostDiscoveryAction`s that will be performed on found devices.
    /// The default action is `LIFXDeviceDiscoveryAction`
    public var actions: [PostDiscoveryAction.Type]
    
    /// The configuration dictionary of `[ConfigurationOption: Any]` that will be used for this device discovery.
    /// See `.defaultConfiguration` for the default values set.
    /// Set this property to account for custom configurations.
    public var configuration: Configration = .defaultConfiguration
    /// When set, allows the user to perform custom actions on with user defined `ConfigurationOption`.
    /// You can assume that most properties of `Device` have already been set and can be used.
    public var onConfiguration: ((AnyDevice, Configration) -> Void)?

    /// Initializes a `DeviceDiscovery` object
    /// - Parameter identifier: The `DeviceIdentifier` that should be searched for.
    /// - Parameter domain: The `Domain` in which the `DeviceDiscovery` will be looking for.
    public init(_ identifier: DeviceIdentifier, domain: Domain = .local) {
        self.identifier = identifier
        self.domain = domain
        self.devices = []
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        
        // Default actions
        self.actions = [
            LIFXDeviceDiscoveryAction.self
        ]
    }
    
    /// Runs the device discovery with the given timeout.
    /// - Parameter timeout: Specifies how it will wait until the post discovery actions are performed. Default is 30 seconds.
    /// - Returns [DiscoveryResult]: Returns a Array of `DiscoveryResult` containing the found information.
    public func run(_ timeout: TimeInterval = 30) throws -> EventLoopFuture<[DiscoveryResult]> {
        self.browser.delegate = self
        browser.searchForServices(ofType: self.identifier.rawValue, inDomain: self.domain.value)
        
        let now = Date()
        RunLoop.current.run(until: now.addingTimeInterval(timeout))
        logger.notice("Finished device search.")
        let results = try runPostDiscoveryActions()
    
        logger.notice("Finished post discovery actions.")
        return eventLoopGroup.next().makeSucceededFuture(results)
    }
    
    
    public func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String : NSNumber]) {
        print(errorDict)
    }
    
    public func netServiceBrowser(_ browser: NetServiceBrowser, didFindDomain domainString: String, moreComing: Bool) {
        print(domainString)
    }
    
    public func netServiceBrowserWillSearch(_ browser: NetServiceBrowser) {
        logger.info("Looking for devices..")
    }
    
    public func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        logger.info("Found service: \(service)")
        
        let device = AnyDevice(service, identifier: self.identifier)
        devices.append(device)
    }
    
    private func runPostDiscoveryActions() throws -> [DiscoveryResult] {
        var results: [DiscoveryResult] = []
        for device in self.devices {
            logger.debug("Configure device: \(String(describing: device.hostname))")
            // Run configure method for every device that is found.
            onConfiguration?(device, self.configuration)
            
            logger.notice("Performing post discovery actions for \(String(describing: device.hostname))")
            guard let runPostActions = self.configuration.typedValue(for: .runPostActions, to: Bool.self),
                  runPostActions else {
                logger.notice("No post found actions configured for \(String(describing: device.hostname))")
                return []
            }
            var performedActions: PerformedAction = [:]
            for Action in actions {
                logger.info("Running action \(Action.identifier)")
                let act = Action.init()
                guard let foundDevices = try act.run(device, on: self.eventLoopGroup) else {
                    logger.error("Could not retrieve number of found devices for action \(Action.identifier)")
                    continue
                }
                performedActions[Action.identifier] = foundDevices
            }
            results.append(DiscoveryResult(device: device, foundEndDevices: performedActions))
        }
        return results
    }
    
}

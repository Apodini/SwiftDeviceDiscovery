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
public class DeviceDiscovery<T: Device>: NSObject, NetServiceBrowserDelegate, NetServiceDelegate {
    
    typealias Configration = [ConfigurationOption: String]
    typealias PerformedAction = [ActionIdentifier: Int]
    
    private var identifier: DeviceIdentifier
    private var domain: Domain
    
    private let browser = NetServiceBrowser()
    private let logger = Logger(label: "device.discovery: discovery")
    
    private var devices: [T]
    
    /// The `PostDiscoveryAction`s that will be performed on found devices.
    /// The default action is `LIFXDeviceDiscoveryAction`
    var actions: [PostDiscoveryAction.Type]
    
    private var eventLoopGroup: EventLoopGroup
    
    /// Initializes a `DeviceDiscovery` object
    /// - Parameter domain: The `Domain` in which the `DeviceDiscovery` will be looking for.
    public init(domain: Domain) {
        self.identifier = T.identifier
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
        
        let device = T.init(service)
        devices.append(device)
    }
    
    private func runPostDiscoveryActions() throws -> [DiscoveryResult] {
        var results: [DiscoveryResult] = []
        for var device in self.devices {
            logger.debug("Configure device: \(String(describing: device.hostname))")
            device.configure()
            
            logger.notice("Performing post discovery actions for \(String(describing: device.hostname))")
            guard let runPostActions = device.configuration.typedValue(for: .runPostActions, to: Bool.self),
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

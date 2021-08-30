//
//  DeviceDiscovery.swift
//  
//
//  Created by Felix Desiderato on 08/07/2021.
//

import Foundation
import Logging
import NIO

/// Responsible for running a discovery in the given domain for the specified `Device.Type`.
/// The discovery can be configured using the `configuration` property of the device object.
public class DeviceDiscovery: NSObject, NetServiceBrowserDelegate, NetServiceDelegate {
    /// A public typealias for the results of the performed post discvoery actions
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
    
    /// The configuration storage that will be used for this device discovery.
    /// See `.defaultConfiguration` for the default values set.
    /// Add  `ConfigurationProperties` to account for custom configurations.
    public var configuration = ConfigurationStorage.shared
    
    /// Initializes a `DeviceDiscovery` object
    /// - Parameter identifier: The `DeviceIdentifier` that should be searched for.
    /// - Parameter domain: The `Domain` in which the `DeviceDiscovery` will be looking for.
    public init(_ identifier: DeviceIdentifier, domain: Domain = .local) {
        self.identifier = identifier
        self.domain = domain
        self.devices = []
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        
        // Default actions
        self.actions = []
    }
    
    @discardableResult
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
    
    
    public func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String: NSNumber]) {
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
        
        let device = AnyDevice(
            service,
            identifier: self.identifier,
            username: configuration.typedValue(for: .username, to: String.self),
            password: configuration.typedValue(for: .password, to: String.self)
        )
        devices.append(device)
    }
    
    private func sshClient(for device: Device) throws -> SSHClient? {
        guard let ipAddress = device.ipv4Address else {
            return nil
        }
        
        return try SSHClient(username: device.username, password: device.password, ipAdress: ipAddress, autoBootstrap: false)
    }
    
    private func runPostDiscoveryActions() throws -> [DiscoveryResult] {
        var results: [DiscoveryResult] = []
        for device in self.devices {
            logger.notice("Performing post discovery actions for \(String(describing: device.hostname))")
            guard let runPostActions = self.configuration.typedValue(for: .runPostActions, to: Bool.self),
                  runPostActions else {
                      logger.notice("No post found actions configured for \(String(describing: device.hostname))")
                      results.append(DiscoveryResult(device: device, foundEndDevices: [:]))
                      continue
                  }
            var performedActions: PerformedAction = [:]
            let sshClient = try sshClient(for: device)
            
            for actionType in actions {
                logger.info("Running action \(actionType.identifier)")
                let act = actionType.init()
                let foundDevices = try act.run(device, on: self.eventLoopGroup, client: sshClient).wait()
                
                logger.info("Found \(foundDevices) devices of type \(actionType.identifier) for \(String(describing: device.hostname))")
                
                performedActions[actionType.identifier] = foundDevices
            }
            results.append(DiscoveryResult(device: device, foundEndDevices: performedActions))
        }
        return results
    }
}

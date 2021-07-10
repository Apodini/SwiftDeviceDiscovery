//
//  File.swift
//  
//
//  Created by Felix Desiderato on 08/07/2021.
//

import Foundation
import Network
import Logging
import NIOLIFX
import NIO

public class DeviceDiscovery<T: Device>: NSObject, NetServiceBrowserDelegate, NetServiceDelegate {
    
    typealias Configration = [ConfigurationOption: String]
    
    private var identifier: DeviceIdentifier
    private var domain: Domain
    
    private let browser = NetServiceBrowser()
    private let logger = Logger(label: "device.discovery: discovery")
    
    private var devices: [T]
    
    private var eventLoopGroup: EventLoopGroup
    
    public init(domain: Domain) {
        self.identifier = T.identifier
        self.domain = domain
        self.devices = []
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    }
    
    public func run(_ timeout: TimeInterval = 30) throws -> EventLoopFuture<[T]> {
        self.browser.delegate = self
        browser.searchForServices(ofType: self.identifier.rawValue, inDomain: self.domain.value)
        
        let now = Date()
        RunLoop.current.run(until: now.addingTimeInterval(timeout))
        logger.notice("Finished device search.")
        
        for device in self.devices {
            try runPostDiscoveryActions(for: device)
        }
        logger.notice("Finished post discovery actions.")
        return eventLoopGroup.next().makeSucceededFuture(self.devices)
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
        
        let device = T.convert(from: service)
        //        runPostFoundActions(for: device)
        devices.append(device)
    }
    
    private func runPostDiscoveryActions(for device: T) throws {
        logger.notice("Performing post discovery actions for \(String(describing: device.hostname))")
        
        guard let runPostActions = device.configuration.typedValue(for: .runPostActions, to: Bool.self),
              runPostActions else {
            logger.notice("No post found actions configured for \(String(describing: device.hostname))")
            return
        }
        logger.notice("Searching for Lifx devices")
        var networkDevice: NIONetworkDevice? {
            let networkInterfaces = try! System.enumerateDevices()
            for interface in networkInterfaces {
                if case .v4 = interface.address, interface.name == "en0" {
                    return interface
                }
            }
            return nil
        }
        guard let netDevice = networkDevice else { return }
        
        let manager = try LIFXDeviceManager(using: netDevice, on: eventLoopGroup, logLevel: .info)
        try manager.discoverDevices().wait()
    }
    
}

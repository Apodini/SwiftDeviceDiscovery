//
// This source file is part of the Apodini open source project
//
// SPDX-FileCopyrightText: 2019-2021 Paul Schmiedmayer and the Apodini project authors (see CONTRIBUTORS.md) <paul.schmiedmayer@tum.de>
//
// SPDX-License-Identifier: MIT
//

import Foundation
import Logging
import NIO
#if os(Linux)
import NetService
#endif

/// Responsible for running a discovery in the given domain for the specified `Device.Type`.
/// The discovery can be configured using the `configuration` property of the device object.
public class DeviceDiscovery: NSObject, NetServiceBrowserDelegate, NetServiceDelegate {
    /// Defines the type of the post discovery action that will be performed on the found device.
    public enum PostActionType {
        /// Use to pass a `PostDiscoveryAction` object that has been implemented in Swift.
        case action(PostDiscoveryAction.Type)
        /// Use to pass a `DockerDiscoveryAction`, which defines an input from a docker image.
        /// This image does not have to be written in Swift.
        case docker(DockerDiscoveryAction)
        
        public var identifier: ActionIdentifier {
            switch self {
            case .action(let PostAction): // swiftlint:disable:this identifier_name
                return PostAction.identifier
            case .docker(let dockerAction):
                return dockerAction.identifier
            }
        }
    }
    
    /// A public typealias for the results of the performed post discvoery actions
    typealias PerformedAction = [ActionIdentifier: Int]
    
    private var identifier: DeviceIdentifier
    private var domain: Domain
    private var eventLoopGroup: EventLoopGroup
    
    private let browser = NetServiceBrowser()
    private let logger: Logger
    
    private var devices: [Device]
    
    /// The `PostDiscoveryAction`s that will be performed on found devices.
    /// The default action is `LIFXDeviceDiscoveryAction`
    private var actions: [PostActionType]
    
    /// The configuration storage that will be used for this device discovery.
    /// See `.defaultConfiguration` for the default values set.
    /// Add  `ConfigurationProperties` to account for custom configurations.
    public var configuration = ConfigurationStorage.shared
    
    /// Initializes a `DeviceDiscovery` object
    /// - Parameter identifier: The `DeviceIdentifier` that should be searched for.
    /// - Parameter domain: The `Domain` in which the `DeviceDiscovery` will be looking for.
    /// - Parameter logger: The Logger used during the lifetime of the discovery
    public init(
        _ identifier: DeviceIdentifier,
        domain: Domain = .local,
        logger: Logger = Logger(label: "device.discovery: discovery")
    ) {
        self.identifier = identifier
        self.domain = domain
        self.devices = []
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        
        // Default actions
        self.actions = []
        self.logger = logger
    }
    
    @discardableResult
    /// Runs the device discovery with the given timeout.
    /// - Parameter timeout: Specifies how it will wait until the post discovery actions are performed. Default is 30 seconds.
    /// - Returns [DiscoveryResult]: Returns a Array of `DiscoveryResult` containing the found information.
    public func run(_ timeout: TimeInterval = 0.25) throws -> EventLoopFuture<[DiscoveryResult]> {
        self.browser.delegate = self
        browser.searchForServices(ofType: self.identifier.rawValue, inDomain: self.domain.value)

        let now = Date()
        RunLoop.current.run(until: now.addingTimeInterval(timeout))
        
        logger.notice("Finished device search.")
        let results = try runPostDiscoveryActions()
        
        logger.notice("Finished post discovery actions.")
        return eventLoopGroup.next().makeSucceededFuture(results)
    }
    
    /// Register multiple `PostActionType`s that will be performed on found devices.
    /// - Parameter types: One or multiple `PostActionType`
    public func registerActions(_ types: PostActionType...) {
        self.actions.append(contentsOf: types)
    }
    
    /// Register an array of `PostActionType`s that will be performed on found devices.
    /// - Parameter types: An array of `PostActionType`.
    public func registerActions(_ types: [PostActionType]) {
        self.actions.append(contentsOf: types)
    }
    
    public func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String: NSNumber]) {
        logger.error("\(errorDict)")
    }
    
    public func netServiceBrowser(_ browser: NetServiceBrowser, didFindDomain domainString: String, moreComing: Bool) {
        logger.error("\(domainString)")
    }
    
    public func netServiceBrowserWillSearch(_ browser: NetServiceBrowser) {
        logger.info("Looking for devices..")
    }
    
    public func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        let device = Device(
            service,
            identifier: self.identifier,
            username: configuration.typedValue(for: .username, to: String.self),
            password: configuration.typedValue(for: .password, to: String.self)
        )
        guard
            device.ipv4Address != nil,
            !(device.ipv4Address?.isEmpty ?? true),
            !devices.contains(where: { $0.ipv4Address == device.ipv4Address })
        else {
            return
        }
        logger.info("Found device: \(device.description)")
        
        
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
                
                var foundDevices: Int
                switch actionType {
                case .action(let PostDiscoveryAction): // swiftlint:disable:this identifier_name
                    let act = PostDiscoveryAction.init() // swiftlint:disable:this explicit_init
                    foundDevices = try act.run(device, on: self.eventLoopGroup, client: sshClient).wait()
                case .docker(let dockerDiscoveryAction):
                    foundDevices = try runDockerImage(dockerDiscoveryAction, sshClient: sshClient)
                }
                
                logger.info("Found \(foundDevices) devices of type \(actionType.identifier) for \(String(describing: device.hostname))")
                
                performedActions[actionType.identifier] = foundDevices
            }
            
            results.append(DiscoveryResult(device: device, foundEndDevices: performedActions))
        }
        return results
    }
    
    private func runDockerImage(_ dockerAction: DockerDiscoveryAction, sshClient: SSHClient?) throws -> Int {
        precondition(dockerAction.options.containsVolume(), "The provided options don't contain the volume")
        
        guard let credentials = dockerAction.options.getLoginCredentials() else {
            throw DiscoveryError("Unable to find credetials in the given actions.")
        }
        
        try sshClient?.bootstrap()
        try sshClient?.executeAsBool(cmd: "sudo docker login -u \(credentials.0) -p \(credentials.1)")
        try sshClient?.executeAsBool(cmd: "sudo chmod 777 \(dockerAction.fileUrl.path)")
        
        let command: String = {
            let cmd: String = "sudo docker run --rm "
            let args = dockerAction.options.map { $0.argument }.joined(separator: " ")
            return cmd
                .appending(args)
                .appending(" \(dockerAction.imageName)")
                .appending(" \(dockerAction.options.map { $0.command }.joined(separator: " "))")
        }()
        
        try sshClient?.executeAsBool(cmd: command)
        
        var responseString = ""
        sshClient?.executeWithAssertion(cmd: "cat \(dockerAction.fileUrl.path)", responseHandler: { response in
            responseString = response
        })
        // swiftlint:disable:next force_unwrapping
        let responseData = responseString.data(using: .utf8)!
        return try JSONDecoder().decode(Int.self, from: responseData)
    }
    
    /// Stops any running search. If you want to run multiple searchs, make sure to run `stop` after each.
    public func stop() {
        browser.stop()
    }
}

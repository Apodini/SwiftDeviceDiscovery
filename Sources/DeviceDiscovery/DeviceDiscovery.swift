//
//  DeviceDiscovery.swift
//  DeviceDiscovery
//
//  Created by Felix Desiderato on 31.05.21.
//

import Foundation
import Network
import Logging

class DeviceDiscovery: NSObject, Discoverable {
    
    private let pipe = Pipe()
    var devices: [DiscoverableObject & SSHable] = []
    
    private let logger = Logger(label: "DeviceDiscovery")
    
    private var sshClient: SSHClient?
    
    var pathToDeployableSystem: String = "/Users/felixdesiderato/Documents/TestWebService"
    
    func execute(_ timeout: TimeInterval) throws {
        try createDockerImage()
        
        let browser = NetServiceBrowser()
        browser.delegate = self
        browser.searchForServices(ofType: CONFIG.deviceType, inDomain: CONFIG.domain)
        RunLoop.current.run()
    }
    
    func shutdown() throws -> Int64 {
        fatalError("Not yet implemented")
        //TODO: Cleanup
    }
    
    func createDockerImage() throws {
        let task = Task(["bash", "/Users/felixdesiderato/Documents/Test/docker-script.sh"])
        let result = task.run()
        if result != EXIT_SUCCESS {
            logger.error("Failed to build docker image")
            return
        }
//        let pathURL = URL(fileURLWithPath: pathToDeployableSystem).appendingPathComponent("docker")
//        var isDir: ObjCBool = true
//        if !FileManager.default.fileExists(atPath: pathURL.path, isDirectory: &isDir) {
//            try! FileManager.default.createDirectory(at: pathURL, withIntermediateDirectories: false, attributes: nil)
//        }
//
//        let imageName = "\(CONFIG.deviceType).\(CONFIG.domain)"
//        let buildTask = Task(["docker", "build", "-t", imageName, pathToDeployableSystem], lauchPath: "/usr/local/bin/docker")
//        let result = buildTask.run()
//        if result != EXIT_SUCCESS {
//            logger.error("Failed to build docker image")
//            return
//        }
//        let saveTask = Task(["cd \(pathURL.absoluteString)", "docker save \(imageName):latest | gzip > \(imageName).tar.gz"])
//        let saveResult = saveTask.run()
//        if saveResult != EXIT_SUCCESS {
//            print(saveResult)
//            logger.error("failed to save image.")
//            return
//        }
    }
}

extension DeviceDiscovery: NetServiceBrowserDelegate {
    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        logger.info("Found service: \(service)")
        let device = RaspberryPi(from: service)
        devices.append(device)
        print(pathToDeployableSystem)
        do {
            var deploymentHandler = DeploymentHandler(
                logger: self.logger,
                remoteDirectoryPath: self.remoteDirectoryPath,
                object: device,
                source: .local(pathToDeployableSystem: self.pathToDeployableSystem)
            )
            
            try deploymentHandler.run()
        } catch {
            print(error)
        }
    }

    func netServiceBrowserWillSearch(_ browser: NetServiceBrowser) {
        logger.info("Starting device discovery...")
    }
    
    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        guard let device = devices.first(where: { $0.macAddress == service.macAddress() }) else { fatalError("device not found")}
        do {
            let client = try SSHClient(device)
            try client.assertSuccessfulExecution(["sudo rm -d -r \(self.remoteDirectoryPath)"], silent: false)
        } catch {
            print(error)
        }
        logger.info("Removed service: \(service)")
    }
    
    func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser) {
        logger.info("Stopped searching.")
    }
}

extension NetService {
    func hostname() -> String {
        name.components(separatedBy: .whitespaces)[0]
    }
    
    func macAddress() -> Int64? {
        let address = name.components(separatedBy: .whitespaces)[1]
            .replacingOccurrences(of: ["[", "]", ":"], with: "")
        return Int64(address, radix: 16)
    }
}

extension String {
    func replacingOccurrences(of occurrences: [String], with: String) -> String {
        var result = self
        for occurrence in occurrences {
            result = result.replacingOccurrences(of: occurrence, with: with)
        }
        return result
    }
}

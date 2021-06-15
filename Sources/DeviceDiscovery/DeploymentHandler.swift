//
//  DeploymentHandler.swift
//  DeviceDiscovery
//
//  Created by Felix Desiderato on 28.05.21.
//

import Foundation
import Network
import Shout
import Logging


enum DeploymentError: String, Error {
    case copyFailed
    case dockerInstallationFailed
    case dockerComposeInstallationFailed
    case directoryCreationFailed
    case sshInjectionFailed
}


/**
 Responsible for the deployment of given `Source` object to the passed `DiscoverableObject & SSHable` object.
 The deployment includes the installation of docker if necessaryt
 */
struct DeploymentHandler {
    typealias Object = DiscoverableObject & SSHable
    
    enum Source {
        case local(pathToDeployableSystem: String)
        case git(repositoryURL: String)
    }
    
    let logger: Logger
    var sshClient: SSHClient?
    let remoteDirectoryPath: String
    let object: Object
    let source: Source
    
    private var sourceFolderName: String {
        switch source {
        case .git(repositoryURL: let repositoryURL):
            fatalError("Not yet implemented")
        case .local(pathToDeployableSystem: let pathToDeployableSystem):
            let url = URL(fileURLWithPath: pathToDeployableSystem, isDirectory: true)
            return url.lastPathComponent
        }
    }
    
    /**
        Responsible for executing the deployment by iterating through the deployment steps
     */
    mutating func run() throws {
        logger.info("#############")
        logger.info("Starting deployment on \(object.hostname.unsafelyUnwrapped)")
        logger.info("#############")
        do {
            sshClient = try SSHClient(object)
        } catch {
            handleError(.sshInjectionFailed)
        }
        
        try installDockerIfNeeded(object)
        try createDirectoryIfNeeded(object)
        
        switch source {
        case .local(pathToDeployableSystem: let pathToDeployableSystem):
            try copyResources(object, deployableSystem: pathToDeployableSystem)
        case .git(repositoryURL: _):
            fatalError("Not yet supported")
        }
        try createAndRunDockerImage(object)
        
        sshClient = nil
        
        
    }
    
    /**
        Checks if docker is already installed on the `object`. If not, it installs the latest version
     */
    private func installDockerIfNeeded(_ object: Object) throws {
        logger.info("Installing Docker if needed ...")
        try sshClient?.execute("docker -v", silent: false)
        if try sshClient?.execute("docker -v", silent: false) != EXIT_SUCCESS {
            try sshClient?.assertSuccessfulExecution(["curl -fsSL https://get.docker.com -o get-docker.sh", "sudo sh get-docker.sh"], silent: false)
        }
        logger.info("Installing Docker Compose if needed ...")
        if try sshClient?.execute("docker-compose --version") != EXIT_SUCCESS {
            logger.info("Couldn't find a Docker Compose binary. Installing it...")
            try sshClient?.assertSuccessfulExecution(["sudo pip3 install docker-compose"], silent: false)
        }
    }
    
    /**
        Creates a separate directory on the `object` that contains the sources that should be deployed.
     */
    private func createDirectoryIfNeeded(_ object: Object) throws {
        let userName: String = object.username + ":" + object.username
        
        try sshClient?.execute("sudo mkdir " + remoteDirectoryPath, silent: false)
        try sshClient?.execute("sudo chown \(userName) /usr/deployment", onCompletion: { result in
            guard result else { return handleError(.directoryCreationFailed) }
            logger.info("Created directory successfully.")
        })
    }

    /**
        Creates the docker image from the `dockerfile` in the source directory. If successful, it runs the created image in a new container.
        The container name is specified by the `hostname` of the device.
     */
    private func createAndRunDockerImage(_ device: Object) throws {
        guard let hostname = device.hostname else { fatalError("Device has no hostname") }
        let imageName = String(format: "%@.%@", hostname, device.id.uuidString).lowercased()
        let sourcePath = remoteDirectoryPath.appending(sourceFolderName)
        print(sourcePath)
        try sshClient?.execute("cd \(sourcePath)")
        try sshClient?.assertSuccessfulExecution(["sudo docker build -t \(imageName) \(sourcePath)"], silent: false)
//        try sshClient?.assertSuccessfulExecution(["docker-compose up"])
//        logger.info("Successfully created docker image \(imageName)")
        logger.info("Starting docker instance..")
        
        /// Remove all old running or existing containers with the name before starting the new one
        try sshClient?.execute("sudo docker stop \(hostname)", silent: false)
        try sshClient?.execute("sudo docker rm \(hostname)", silent: false)

        try sshClient?.assertSuccessfulExecution(["sudo docker run -dp 3000:3000  --name \(hostname) \(imageName)"], silent: false)
        
    }
    
    /**
        If `source=.local`, this method transfers the local source directory to the specified directory of the device where it should be deployed on.
     */
    private func copyResources(_ object: Object, deployableSystem: String) throws {
        logger.info("Copying resources to device")
        
        let remoteInput = String(format: "%@:%@", object.sshableHostname(), remoteDirectoryPath)
        let result = try executeLocally([
            "rsync",
            "-avz",
            "-e",
            "'ssh'",
            deployableSystem,
            remoteInput
        ])
        if result != EXIT_SUCCESS {
            return handleError(.copyFailed)
        }
        logger.info("Copied resources successfully to \(remoteDirectoryPath)")
    }

    /**
        Executes given CLI commands on local machine
     */
    private func executeLocally(_ arguments: [String]) throws -> Int32 {
        let process = Process()
        let stdin = Pipe()
        let stdout = Pipe()
        let stderror = Pipe()
        process.launchPath = "/usr/bin/env"
        process.arguments = arguments
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = stderror
        process.launch()
        process.waitUntilExit()
        return process.terminationStatus
    }
    
    /**
        Logs an understandable error message for the given error.
     */
    private func handleError(_ type: DeploymentError) {
        logger.error("Execution failed. Error: \(type.rawValue)")
        exit(SIGTERM)
    }
}

extension Pipe {
    func readablePipeContent() -> String? {
        let theTaskData = fileHandleForReading.readDataToEndOfFile()
        let stringResult = String(data: theTaskData, encoding: .utf8)
        return stringResult
    }
}

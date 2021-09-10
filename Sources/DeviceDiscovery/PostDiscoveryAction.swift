//
//  PostDiscoveryAction.swift
//  
//
//  Created by Felix Desiderato on 10/07/2021.
//

import Foundation
import NIO

/// An identifier object that is used to identify a `PostDiscoveryAction`
public struct ActionIdentifier: RawRepresentable, Hashable, Equatable, Codable {
    public let rawValue: String
    
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
    
    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}

extension ActionIdentifier: CustomStringConvertible {
    public var description: String {
        rawValue
    }
}

/// A protocol that can be implemented to specify a `PostDiscoveryAction`. These will be executed after the discovery phase and
/// allow to for custom actions on the found device. Typically it is used to search for end devices that are connected to the found device.
public protocol PostDiscoveryAction {
    /// The identifier object of a `PostDiscoveryAction`.
    static var identifier: ActionIdentifier { get }
    /// Default empty initializer.
    init()
    /// Performs the `PostDiscoveryAction`.
    /// - Parameter device: The `Device` object the action is performed on
    /// - Parameter eventLoopGroup: A `EventLoopGroup`.
    /// - Parameter client: An unboot `SSHClient` instance. 
    /// - Returns Int: numberOfFoundDevices.
    func run(_ device: Device, on eventLoopGroup: EventLoopGroup, client: SSHClient?) throws -> EventLoopFuture<Int>
}

/// Contains the final results of the discovery. Each result consists of the found `Device` and a dictionary mapping the `ActionIdentifier` of the
/// `PostDiscoveryAction`s that were run for this discovery to the number of the found devices for that identifier.
public struct DiscoveryResult {
    /// The device the current discovery instance was looking for
    public let device: Device
    /// All `PostDiscoveryAction`s that ran in this instance and the number of devices that were found under their identifier.
    public let foundEndDevices: [ActionIdentifier: Int]
}

extension DiscoveryResult: Equatable {
    public static func == (lhs: DiscoveryResult, rhs: DiscoveryResult) -> Bool {
        lhs.device.identifier == rhs.device.identifier &&
        lhs.foundEndDevices == rhs.foundEndDevices
    }
}

/// Encapusaltes a post discovery action for a docker image. An instance of this object can be passed to
/// `registerActions` of `DeviceDiscovery` to be executed on the remote device. In contrary to a `PostDiscoveryAction`,
/// the docker image of a `DockerDiscoveryAction` can assume it already on the device.
///
/// **NOTE**
/// The provided docker image need to write the __number__ (as an integer) of results found to the file specified by `fileUrl`.
/// Otherwise the discovery will not be able to execute the action correctly.  It is also recommend to use to the `volume` option
public struct DockerDiscoveryAction {
    /// An identifier for the docker action
    public let identifier: ActionIdentifier
    /// The name of the docker image
    public let imageName: String
    /// The file url to which the results file is saved
    public let fileUrl: URL
    /// The options that will be used when the image is run in a container
    public let options: [DiscoveryDockerOptions]
    
    /// Initializes a new DockerDiscoveryAction.
    ///  - Parameter identifier: An `ActionIdentifier` of the action.
    ///  - Parameter imageName: The name of the docker image.
    ///  - Parameter fileUrl: The url of the file that has been written by the docker container.
    ///  - Parameter options: An array of option that are passed when the image is run in a container.
    public init(
        identifier: ActionIdentifier,
        imageName: String,
        fileUrl: URL,
        options: [DiscoveryDockerOptions] = []
    ) {
        self.identifier = identifier
        self.imageName = imageName
        self.fileUrl = fileUrl
        self.options = options
    }
}

/// Provides common used option when running a docker image in a container.
public enum DiscoveryDockerOptions {
    /// -d: Run the container in detached mode
    case detached
    /// --privileged: Runs the container with privileges
    case privileged
    /// -v hostDir:containerDir. Mounts the container to the given volume.
    case volume(hostDir: String, containerDir: String)
    /// --p hostPort:containerPort. Forwards the port in the container to the port on the host.
    case port(hostPort: Int, containerPort: Int)
    /// The command that will be executed when the container is started
    case command(String)
    /// Needs to be set to log in into the docker repo of the image
    case credentials(username: String, password: String)
    /// Any custom options. Provide them in the common known string format.
    case custom(String)
    
    var argument: String {
        switch self {
        case .detached:
            return "-d"
        case .privileged:
            return "--privileged"
        case let .volume(hostDir, containerDir):
            return "-v \(hostDir):\(containerDir):Z"
        case let .port(hostPort, containerPort):
            return "-p \(hostPort):\(containerPort)"
        case .custom(let options):
            return options
        case .command(_), .credentials(_, _):
            return ""
        }
    }
    
    var command: String {
        switch self {
        case .command(let cmd):
            return cmd
        default:
            return ""
        }
    }
}

extension Array where Element == DiscoveryDockerOptions {
    func containsVolume() -> Bool {
        contains(where: { option in
            if case .volume(_, _) = option {
                return true
            }
            return false
        })
    }
    
    func getLoginCredentials() -> (String, String)? {
        for option in self {
            if case let .credentials(username: username, password: password) = option {
                return (username, password)
            }
        }
        return nil
    }
}

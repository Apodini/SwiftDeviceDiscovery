//
//  SSHClient+FileManager.swift
//  
//
//  Created by Felix Desiderato on 21/07/2021.
//
import Foundation
import NIO
import NIOSSH
import Logging

public extension SSHClient {
    /// A simple remote file manager that offers the basic file operations
    class RemoteFileManager {
        /// SInce one might connect to devices running different OSs, this is reflected by this enum
        enum OperatingSystem {
            case linux, windows, mac

            var osSpecificPrefix: String {
                switch self {
                case .linux:
                    return "sudo "
                case .windows, .mac:
                    return ""
                }
            }
        }

        private var client: SSHClient
        private var operatingSystem: OperatingSystem

        /// Initializes a new `RemoteFileManager`
        /// - Parameter client: the `SSHClient` the file operations are executed on
        /// - Parameter logger: A logger instance used for output
        /// - Parameter os: The os of the remote device. Default is linux
        init(_ client: SSHClient, operatingSystem: OperatingSystem = .linux) {
            self.client = client
            self.operatingSystem = operatingSystem
        }

        private func command(_ command: String) -> String {
            let prefix: String = operatingSystem.osSpecificPrefix
            return prefix.appending(command)
        }

        private func dirExists(on path: URL) throws -> Bool {
            try client.executeAsBool(cmd: "cd \(path.path)")
        }

        /// Creates a directory at the given `URL` with the given permissions
        /// - Parameter path: The url containing the directory that will be created
        /// - Parameter permissions: The posix permissions that should be set for the directory
        /// - Parameter force: Flag indicating if an existing directory should be overridden by force
        public func createDir(on path: URL, permissions: Int, force: Bool = false) throws {
            if try dirExists(on: path) {
                if force {
                    self.remove(at: path, isDir: true)
                } else {
                    print("Directory already exists and force was set to false")
                    return
                }
            }
            client.executeWithAssertion(cmd: command("mkdir -m \(permissions) \(path.path)"), responseHandler: nil)
            print("Directory at \(path.path) created.")
        }
        
        /// Moves a directory from a given `URL` to a given destination `URL`.
        /// - Parameter origin: The url containing the directory that will be moved
        /// - Parameter destination: The url the directory that will be moved to
        /// - Returns EventLoopFuture<Void>: Return type
        public func move(from origin: URL, to destination: URL) {
            client.executeWithAssertion(cmd: command("mv \(origin.path) \(destination.path)"), responseHandler: nil)
            print("Moved \(origin.lastPathComponent) from \(origin.path) to \(destination.path)")
        }
        
        /// Removes a file or directoy at the given `URL`.
        /// - Parameter path: The url containing the directory or file.
        /// - Parameter isDir: Set if to-be-deleted file is a directory
        /// - Parameter recursive: If directory, set to true if the directory should be deleted recursively. Default value is true
        /// - Parameter force: If set, deletes the directory by force. Default value is true
        public func remove(at path: URL, isDir: Bool, recursive: Bool = true, force: Bool = true) {
            let options: String = ""
                .appending(isDir ? "d" : "")
                .appending(recursive ? "r" : "")
                .appending(force ? "f" : "")
            client.executeWithAssertion(cmd: command("rm -\(options) \(path.path)"))
            print("Removed \(path.path)")
        }
    }
}

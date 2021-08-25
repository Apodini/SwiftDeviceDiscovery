//
//  Task.swift
//  Task
//
//  Created by Felix Desiderato on 14/08/2021.
//

import Foundation

/// A convenient class that encapsulates a `Process` and
/// bundles often used functionality for `PostDiscoveryAction`s.
/// It allows the execution commands on both local and remote devices.
public class Task {
    let captureOutput: Bool
    let remoteDevice: Device?
    let arguments: [String]
    
    let executableName: String
    let executableURL: URL
    let workingDirectory: URL?
    
    var process: Process
    
    let stdin = Pipe()
    let stdout = Pipe()
    let stderr = Pipe()
    
    /// Initializes a new `Task`.
    public init(
        _ executableName: String,
        arguments: [String],
        captureOutput: Bool = false,
        workingDirectory: URL? = nil,
        remoteDevice: Device? = nil
    ) throws {
        self.executableName = executableName
        self.executableURL = try Self.findExecutable(executableName)
        self.workingDirectory = workingDirectory
        
        self.arguments = arguments
        self.captureOutput = captureOutput
        self.remoteDevice = remoteDevice
        
        self.process = Process()
        try setup()
    }
    
    private func setup() throws {
        process.executableURL = executableURL
        process.arguments = arguments
        
        if executableName == "ssh" {
            guard let remoteDevice = remoteDevice else {
                throw DiscoveryError("Want to execute Task remotely, but no device was not specified.")
            }
            
            let defaultArgs = ["\(remoteDevice.username)@\(remoteDevice.ipv4Address)"]
            if let workingDirectory = workingDirectory {
                process.arguments = defaultArgs
                    .appending((["cd /\(workingDirectory)"] + arguments).joined(separator: " && "))
            } else {
                process.arguments = defaultArgs.appending(contentsOf: arguments)
            }
        }
        
        if captureOutput {
            process.standardInput = stdin
            process.standardOutput = stdout
            process.standardError = stderr
        }
    }
    
    /// Launchs the task synchronously.
    public func launch() throws {
        try process.run()
        process.waitUntilExit()
    }
    
    /// Reads the Standard input pipe of the task. Works only if `captureOutput` has been set.
    public func readTaskInput() throws -> String {
        try stdin.readContent()
    }
    
    /// Reads the Standard output pipe of the task. Works only if `captureOutput` has been set.
    public func readTaskOutput() throws -> String {
        try stdout.readContent()
    }
    
    /// Reads the Standard error pipe of the task. Works only if `captureOutput` has been set.
    public func readTaskError() throws -> String {
        try stderr.readContent()
    }
    
    private static func findExecutable(_ binaryName: String) throws -> URL {
        guard let searchPaths = ProcessInfo.processInfo.environment["PATH"]?.components(separatedBy: ":") else {
            throw DiscoveryError("Unable to find executable \(binaryName)")
        }
        for searchPath in searchPaths {
            let executableUrl = URL(fileURLWithPath: searchPath, isDirectory: true)
                .appendingPathComponent(binaryName, isDirectory: false)
            if FileManager.default.fileExists(atPath: executableUrl.path) {
                return executableUrl
            }
        }
        throw DiscoveryError("Unable to find executable \(binaryName)")
    }
}

extension Pipe {
    func readContent() throws -> String {
        if let data = try self.fileHandleForReading.readToEnd(), let content = String(data: data, encoding: .utf8) {
            return content
        }
        throw DiscoveryError("Unable to read content from pipe")
    }
}

extension Array {
    func appending(_ element: Element) -> [Element] {
        var seq = self
        seq.append(element)
        return seq
    }
    
    func appending(contentsOf newElements: [Element]) -> [Element] {
        var seq = self
        seq.append(contentsOf: newElements)
        return seq
    }
}

//
//  File.swift
//  
//
//  Created by Felix Desiderato on 08/07/2021.
//

import Foundation
import NIO
import NIOSSH
import Logging


public class SSHClient {
    
    static let logger = Logger(label: "device.discovery.ssh")
    
    internal let username: String
    internal let ipAdress: String //"192.168.2.112"
    
    private let password: String
    private let port: Int //22
    
    private var channel: Channel?
    private var childChannel: Channel?
    
    public var automaticChildChannelCreation: Bool = true
    
    public private(set) lazy var fileManager: RemoteFileManager = RemoteFileManager(self)
    
    let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    
    public init(username: String, password: String, ipAdress: String, port: Int = 22, autoBootstrap: Bool = true) throws {
        self.username = username
        self.password = password
        self.ipAdress = ipAdress
        self.port = port
        if autoBootstrap {
            try self.bootstrap()
        }
    }
    
    deinit {
        try! group.syncShutdownGracefully()
        try! childChannel?.close().wait()
        try! channel?.close().wait()
    }
    
    private func bootstrap() throws {
        let clientBootstrap = ClientBootstrap(group: group)
            .channelInitializer { channel in
                channel.pipeline.addHandlers([NIOSSHHandler(role: .client(.init(userAuthDelegate: InteractivePasswordPromptDelegate(username: self.username, password: self.password), serverAuthDelegate: AcceptAllKeysDelegate())), allocator: channel.allocator, inboundChildChannelInitializer: nil), ErrorHandler()])
            }
            .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .channelOption(ChannelOptions.socket(SocketOptionLevel(IPPROTO_TCP), TCP_NODELAY), value: 1)
        
        self.channel = try clientBootstrap.connect(host: self.ipAdress, port: self.port).wait()
        
        let childChannel: Channel = try! channel!.pipeline.handler(type: NIOSSHHandler.self).flatMap { sshHandler in
            let promise = self.channel!.eventLoop.makePromise(of: Channel.self)
            sshHandler.createChannel(promise) { childChannel, channelType in
                guard channelType == .session else {
                    return self.channel!.eventLoop.makeFailedFuture(SSHClientError.invalidChannelType)
                }
                return childChannel.pipeline.addHandlers([ExecutionHandler(), ErrorHandler()])
            }
            return promise.futureResult
        }.wait()
        self.childChannel = childChannel
    }
    
    private func createNewChildChannelIfNecessary() throws {
        guard let channel = channel, childChannel?.isActive == false else {
            return
        }
        let childCh: Channel = try! channel.pipeline.handler(type: NIOSSHHandler.self).flatMap { sshHandler in
            let promise = channel.eventLoop.makePromise(of: Channel.self)
            sshHandler.createChannel(promise) { childChannel, channelType in
                guard channelType == .session else {
                    return self.channel!.eventLoop.makeFailedFuture(SSHClientError.invalidChannelType)
                }
                return childChannel.pipeline.addHandlers([ExecutionHandler(), ErrorHandler()])
            }
            return promise.futureResult
        }.wait()
        self.childChannel = childCh
    }
    
    @discardableResult
    private func triggerUserOutboundEvent(_ command: String, responseHandler: ((String, Int32) -> Void)?) throws -> EventLoopFuture<Void> {
        guard let childChannel = childChannel else { throw SSHClientError.invalidChannelType }
        let byteBuffer = ByteBuffer(string: command)
        let promise = childChannel.eventLoop.makePromise(of: Void.self)
        childChannel.triggerUserOutboundEvent((byteBuffer, responseHandler), promise: promise)
        return promise.futureResult
    }
    
    //    public func execute<T>(args: [String], responseHandler: ((String, Int32) -> Void)?, returnType: T.Type) throws -> EventLoopFuture<T> {
    //        let command = args.joined(separator: " && ")
    //        let promise = childChannel.unsafelyUnwrapped.eventLoop.makePromise(of: T.self)
    //
    //        return promise.futureResult
    //        if let BoolType = T.self as? Bool.Type {
    //            return try executeBool(args: args, responseHandler: responseHandler)
    //        }
    //        let promise = childChannel.unsafelyUnwrapped.eventLoop.makePromise(of: T.self)
    //    }
    
    public func execute(args: [String], responseHandler: ((String, Int32) -> Void)?) throws -> EventLoopFuture<Void> {
        try createNewChildChannelIfNecessary()
        let command = args.joined(separator: " && ")
        return try self.triggerUserOutboundEvent(command, responseHandler: responseHandler)
    }
    
    public func execute(args: [String], responseHandler: ((String, Int32) -> Void)? = nil) throws -> EventLoopFuture<Bool> {
        try createNewChildChannelIfNecessary()
        let command = args.joined(separator: " && ")
        let promise = childChannel.unsafelyUnwrapped.eventLoop.makePromise(of: Bool.self)
        
        let responseHandler: (String, Int32) -> Void = { response, exitCode in
            responseHandler?(response, exitCode)
            promise.succeed(exitCode == EXIT_SUCCESS)
        }
        try self.triggerUserOutboundEvent(command, responseHandler: responseHandler)
        return promise.futureResult
    }
    
    public func assertSuccessfulExecution(args: [String], responseHandler: ((String, Int32) -> Void)?) {
        assert(try! self.execute(args: args, responseHandler: responseHandler).wait(), "Successful execution assertion failed for \(args)")
    }
    
    public func bootstrapManually() throws {
        try self.bootstrap()
    }
}

public class RemoteFileManager {
    
    public enum OS {
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
    private var os: OS
    private var localFileManager: FileManager
    private var workingDir: URL?
    
    private var logger: Logger = Logger(label: "device.discovery.fileManager")
    
    public init(_ client: SSHClient, os: OS = .linux) {
        self.client = client
        self.os = os
        self.localFileManager = FileManager.default
    }
    
    private func command(_ command: String) -> String {
        let prefix: String = os.osSpecificPrefix
        return prefix.appending(command)
    }
    
    private func dirExists(on path: URL) throws -> Bool {
        try client.execute(args: ["cd \(path.path)"], responseHandler: nil).wait()
    }
    
    private func setPermissions(_ permissions: Int = 777, for path: URL) -> String {
        command("chmod \(permissions) \(path.path)")
    }
    
    public func createDir(on path: URL, forceRecreation: Bool = true) throws {
        guard !(try dirExists(on: path)) else {
            throw SSHError.remoteDirAlreadyExists
        }
        
        client.assertSuccessfulExecution(args: [command("mkdir \(path)")], responseHandler: nil)
        client.assertSuccessfulExecution(args: [setPermissions(for: path)], responseHandler: nil)
        logger.debug("Directory at \(path) created.")
    }
    
    public func copyResources(from origin: URL, to destination: URL) throws -> (Process.TerminationReason, String?) {
        if try !client.execute(args: ["cd \(destination.path)"]).wait() {
            // no dir exists, so create it
            try self.createDir(on: destination)
        }
        if !localFileManager.fileExists(atPath: origin.path) {
            throw SSHClientError.rsyncLocalDirNotFound
        }
        
        // follows pattern username@hostname:pathToRemoteDir
        let remotePath: String = String(format: "%@@%@:%@", client.username, client.ipAdress, destination.path)
        
        let stdin = Pipe()
        let stdout = Pipe()
        
        let process = Process()
        process.executableURL = findExecutable(named: "rsync")
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = stdout
        process.arguments = [
            "-avz",
            "-e",
            "'ssh'",
            origin.path,
            remotePath]
        process.launch()
        process.waitUntilExit()
        logger.debug("Process with args: \(process.arguments)")
        logger.debug("Output: \(stdout.readablePipeContent())")
        return (process.terminationReason, stdout.readablePipeContent())
    }
    
    private func findExecutable(named binaryName: String) -> URL? {
        guard let searchPaths = ProcessInfo.processInfo.environment["PATH"]?.components(separatedBy: ":") else {
            return nil
        }
        for searchPath in searchPaths {
            let executableUrl = URL(fileURLWithPath: searchPath, isDirectory: true)
                .appendingPathComponent(binaryName, isDirectory: false)
            if FileManager.default.fileExists(atPath: executableUrl.path) {
                return executableUrl
            }
        }
        return nil
    }
}

extension Pipe {
    func readablePipeContent() -> String? {
        let theTaskData = fileHandleForReading.readDataToEndOfFile()
        let stringResult = String(data: theTaskData, encoding: .utf8)
        return stringResult
    }
}

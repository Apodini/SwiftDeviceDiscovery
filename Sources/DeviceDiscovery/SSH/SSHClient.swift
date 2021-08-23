//
//  SSHClient.swift
//  
//
//  Created by Felix Desiderato on 08/07/2021.
//
// This code is based on the SwiftNIO SSH project: https://github.com/apple/swift-nio-ssh
//

import Foundation
import NIO
import NIOSSH
import Logging

/// Manages the connection to a remote device. It allows to execute commands remotely.
/// The connection is open until the object is deinitialized or `close()` is called.
public class SSHClient {
    /// Logs events of the `SSHClient`
    static let logger = Logger(label: "device.discovery.ssh")
    
    internal let username: String
    internal let ipAdress: String //"192.168.2.112"
    
    private let password: String
    private let port: Int //22
    
    private var channel: Channel?
    private var childChannel: Channel?
    
    static var successCode: String = "_cmd_exit_success_0_"
    static var failureCode: String = "_cmd_exit_failure_1_"
    
    private var unwrappedChildChannel: Channel {
        childChannel.unsafelyUnwrapped
    }
    
    /// A instance of `RemoteFileManager` that allows for easy file operations
    public private(set) lazy var fileManager = RemoteFileManager(self)
    
    private let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    
    /// Initializes a new instance of `SSHClient` on which commands can be send to the remote client.
    /// - Parameter username: The username of the remote instance
    /// - Parameter password: The password of the remote instance
    /// - Parameter ipAddress: The ip address/ hostname of the remote instance
    /// - Parameter port: The port of the connection. Default is 22
    /// - Parameter autoBootstrap: If set, bootstraps the connection directly. If false, the user needs to manually call `bootstrap()`. The default is true.
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
        // swiftlint:disable:next force_try
        try! childChannel?.close().wait()
        // swiftlint:disable:next force_try
        try! channel?.close().wait()
        // swiftlint:disable:next force_try
        try! group.syncShutdownGracefully()
    }
    
    /// Bootstraps the client connection.
    /// **DO NOT** call this function directly, unless you initialized the client with `autoBootstrap = false`.
    public func bootstrap() throws {
        let clientBootstrap = ClientBootstrap(group: group)
            .channelInitializer { channel in
                channel.pipeline.addHandlers([
                    NIOSSHHandler(role: .client(.init(
                                            userAuthDelegate: InteractivePasswordPromptDelegate(username: self.username, password: self.password),
                                            serverAuthDelegate: AcceptAllKeysDelegate())),
                                  allocator: channel.allocator,
                                  inboundChildChannelInitializer: nil),
                    ErrorHandler()
                ])
            }
            .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .channelOption(ChannelOptions.socket(SocketOptionLevel(IPPROTO_TCP), TCP_NODELAY), value: 1)
        
        self.channel = try clientBootstrap.connect(host: self.ipAdress, port: self.port).wait()
        
        guard let channel = channel else {
            throw SSHClientError.channelInitializationFailed
        }

        let childChannel: Channel = try channel.pipeline
            .handler(type: NIOSSHHandler.self)
            .flatMap { sshHandler in
                let promise = channel.eventLoop.makePromise(of: Channel.self)
                sshHandler.createChannel(promise) { childChannel, channelType in
                    guard channelType == .session else {
                        return channel.eventLoop.makeFailedFuture(SSHClientError.invalidChannelType)
                    }
                    return childChannel.pipeline.addHandlers([ExecutionHandler(), ErrorHandler()])
                }
                return promise.futureResult
            }
            .wait()
        self.childChannel = childChannel
        try self.unwrappedChildChannel.triggerUserOutboundEvent(SSHChannelRequestEvent.ShellRequest(wantReply: false)).wait()
    }
    
    private func wrapIn(_ value: String) -> ByteBuffer {
        let wrapper = String(format: "%@ && echo %@ || %@\n", value, Self.successCode, Self.failureCode)
        return ByteBuffer(string: wrapper)
    }
    
    /// Executes the given command synchronously and asserts its successful execution by throwing an `SSHError` if the execution failed.
    /// By default, all output is directly printed to stdout.
    /// - Parameter cmd: The execution command
    /// - Parameter responseHandler: A callback function that is called for every chunk of output.
    public func executeWithAssertion(cmd: String, responseHandler: ((String) -> Void)? = nil) {
        let promise = group.next().makePromise(of: Void.self)
        self.unwrappedChildChannel.triggerUserOutboundEvent((self.wrapIn(cmd), responseHandler), promise: promise)
        // swiftlint:disable:next force_try
        try! promise.futureResult.wait()
    }
    
    /// Executes the given command synchronously and returns `true` on a successful execution.
    /// By default, all output is directly printed to stdout.
    /// - Parameter cmd: The execution command
    /// - Parameter responseHandler: A callback function that is called for every chunk of output.
    @discardableResult
    public func execute(cmd: String, responseHandler: ((String) -> Void)? = nil) throws -> Bool {
        let promise = group.next().makePromise(of: Bool.self)
        self.unwrappedChildChannel.triggerUserOutboundEvent(((self.wrapIn(cmd), responseHandler, promise)), promise: nil)
        return try promise.futureResult.wait()
    }
    
    /// Executes a command on the remote device and calls the given responseHandler call-back with the result
    /// - Parameter cmd: The command that is executed remotely
    /// - Parameter responseHandler: The call back function that is call with the result from the request.
    /// - Returns EventLoopFuture<Void>: The void eventloopfuture that is returned
    public func execute(cmd: String, responseHandler: ((String) -> Void)?) throws -> EventLoopFuture<Void> {
        self.unwrappedChildChannel.triggerUserOutboundEvent((self.wrapIn(cmd), responseHandler))
    }
    
    /// Executes the given commands on the remote device.
    /// - Parameter cmds: The commands that is executed remotely
    /// - Returns EventLoopFuture<Void>: The void eventloopfuture that is returned
    public func execute(cmds: [String]) throws -> EventLoopFuture<Void> {
        try EventLoopFuture<Void>
            .reduce(
                Void(),
                cmds.map { cmd in
                    try self.execute(cmd: cmd, responseHandler: nil)
                },
                on: group.next(),
                { _, _ in } // swiftlint:disable:this opening_brace
            )
    }
    
    /// Closes all channels and eventloops.
    public func close() throws {
        try childChannel?.close().wait()
        try channel?.close().wait()
        try group.syncShutdownGracefully()
    }
}

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


class Client {
    
    static let logger = Logger(label: "device.discovery: ssh")
    
    private let username: String
    private let password: String
    private let ipAdress: String //"192.168.2.112"
    private let port: Int //22
    
    private var channel: Channel?
    private var clientBootstrap: ClientBootstrap?
    
    let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    
    init(username: String, password: String, ipAdress: String, port: Int) {
        self.username = username
        self.password = password
        self.ipAdress = ipAdress
        self.port = port
    }
    
    deinit {
        let _ = channel?.close()
    }

    private func bootstrap() -> ClientBootstrap {
        let clientBootstrap = ClientBootstrap(group: group)
            .channelInitializer { channel in
                channel.pipeline.addHandlers([NIOSSHHandler(role: .client(.init(userAuthDelegate: InteractivePasswordPromptDelegate(username: self.username, password: self.password), serverAuthDelegate: AcceptAllKeysDelegate())), allocator: channel.allocator, inboundChildChannelInitializer: nil), ErrorHandler()])
            }
            .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .channelOption(ChannelOptions.socket(SocketOptionLevel(IPPROTO_TCP), TCP_NODELAY), value: 1)
        Self.logger.info("Bootstrap successful")
        return clientBootstrap
    }
    
    func connect() throws {
        self.channel = try bootstrap().connect(to: SocketAddress(ipAddress: self.ipAdress, port: self.port)).wait()
    }
    
    func execute(args: [String]) throws -> String {
        guard let channel = channel else {
            throw SSHError.channelNotFound(msg: "Channel is nil")
        }
        let commands = args.joined(separator: "; ")
        print(commands)
        let resultPromise = channel.eventLoop.makePromise(of: String.self)
        let _ = try channel.pipeline.handler(type: NIOSSHHandler.self).flatMap { sshHandler -> EventLoopFuture<Channel> in
            let promise = channel.eventLoop.makePromise(of: Channel.self)
            sshHandler.createChannel(promise) { childChannel, channelType in
                guard channelType == .session else {
                    return channel.eventLoop.makeFailedFuture(SSHError.invalidChannelType)
                }
                return childChannel.pipeline.addHandlers([
                                                            CommandExecutionHandler(commands, promise: resultPromise),
                                                            ErrorHandler()])
                
            }
            return promise.futureResult
        }.wait()
//        try wrapUp()
        return try resultPromise.futureResult.wait()
    }
    
    func wrapUp() throws {
        try group.syncShutdownGracefully()
        try channel?.close(mode: .all).wait()
    }
}

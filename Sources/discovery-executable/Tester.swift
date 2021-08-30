//
//  Tester.swift
//  
//
//  Created by Felix Desiderato on 11/07/2021.
//

import Foundation
import DeviceDiscovery
import NIO
import NIOSSH

@main
enum Tester {
    static func main() throws {
        //Do something
        let discovery = DeviceDiscovery(DeviceIdentifier("_workstation._tcp."))
        discovery.configuration = [
            .username: "ubuntu",
            .password: "test1234",
            .runPostActions: true
        ]
        try discovery.run(1)
        
        exit(0)
        
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer {
            try! eventLoopGroup.syncShutdownGracefully()
        }

        let matchingInterfaces = try System.enumerateInterfaces().filter {
            // find an IPv4 interface named en0 that has a broadcast address.
            $0.name == "en0" && $0.broadcastAddress != nil
        }

        guard let en0Interface = matchingInterfaces.first, let broadcastAddress = en0Interface.broadcastAddress else {
            print("ERROR: No suitable interface found. en0 matches \(matchingInterfaces)")
            exit(1)
        }
        print(en0Interface.address)
        
        let messageHandler = MessageHandler(broadcast: broadcastAddress)
        // let's bind the server socket
        let bootstrap = DatagramBootstrap(group: eventLoopGroup)
                    .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
                    .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEPORT), value: 1)
                    .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_BROADCAST), value: 1)
                    .channelInitializer { channel in
                        channel.pipeline.addHandlers([messageHandler])
                    }

        let channel = try bootstrap.bind(host: "0.0.0.0", port: 5353).wait()
        let handler: ((ByteBuffer) -> Void) = { buffer in
            print(buffer)
        }
        try channel.triggerUserOutboundEvent((ByteBuffer(string: "Test"), handler)).wait()
    }
}

class MessageHandler: ChannelDuplexHandler {
    typealias InboundIn = AddressedEnvelope<ByteBuffer>
    typealias OutboundIn = (message: ByteBuffer, responseHandler: (ByteBuffer) -> Void)
    typealias OutboundOut = AddressedEnvelope<ByteBuffer>
    
    var broadcastIP: SocketAddress
    
    init(broadcast: SocketAddress) {
        self.broadcastIP = broadcast
    }
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let envelope = self.unwrapInboundIn(data)
        let message = envelope.data
        
        let string = String(buffer: message)
        print(string)
    }
    
    func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let (message, messageResponseHandler) = unwrapOutboundIn(data)
        let test = try! SocketAddress(ipAddress: "224.0.0.251", port: 5353)
        let addressedEnvelope = AddressedEnvelope(remoteAddress: test, data: message)
        context.writeAndFlush(wrapOutboundOut(addressedEnvelope), promise: promise)
    }
    
    func triggerUserOutboundEvent(context: ChannelHandlerContext, event: Any, promise: EventLoopPromise<Void>?) {
        guard let event = event as? (ByteBuffer, (ByteBuffer) -> Void) else {
            return
        }
        
        write(context: context, data: NIOAny(event), promise: promise)
    }
}

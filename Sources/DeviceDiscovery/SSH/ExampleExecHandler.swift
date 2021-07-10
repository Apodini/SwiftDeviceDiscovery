//
//  File.swift
//  
//
//  Created by Felix Desiderato on 06/07/2021.
//

import Dispatch
import NIO
import NIOSSH
import Foundation

final class ExampleExecHandler: ChannelDuplexHandler {
    typealias InboundIn = SSHChannelData
    typealias InboundOut = ByteBuffer
    typealias OutboundIn = ByteBuffer
    typealias OutboundOut = SSHChannelData

    private var completePromise: EventLoopPromise<String>?

    private let command: String
    private let openShell: Bool

    init(command: String, completePromise: EventLoopPromise<String>, openShell: Bool = false) {
        self.completePromise = completePromise
        self.command = command
        self.openShell = openShell
    }

    func handlerAdded(context: ChannelHandlerContext) {
        context.channel.setOption(ChannelOptions.allowRemoteHalfClosure, value: true).whenFailure { error in
            context.fireErrorCaught(error)
        }
    }

    func channelActive(context: ChannelHandlerContext) {
//        let request = SSHChannelRequestEvent.ShellRequest(wantReply: false)
        let request: Any
        if openShell {
            request = SSHChannelRequestEvent.ShellRequest(wantReply: false)
        } else {
            request = SSHChannelRequestEvent.ExecRequest(command: self.command, wantReply: false)
        }
        context.triggerUserOutboundEvent(request).whenFailure { error in
            context.fireErrorCaught(error)
        }
        
        // We need to set up a pipe channel and glue it to this. This will control our I/O.
//        let (ours, theirs) = GlueHandler.matchedPair()
//        context.
//        // Sadly we have to kick off to a background thread to bootstrap the pipe channel.
//        let bootstrap = NIOPipeBootstrap(group: context.eventLoop)
//        context.channel.pipeline.addHandler(ours, position: .last).whenSuccess { _ in
//            DispatchQueue(label: "pipe bootstrap").async {
//                bootstrap.channelOption(ChannelOptions.allowRemoteHalfClosure, value: true).channelInitializer { channel in
//                    channel.pipeline.addHandler(theirs)
//                }.withPipes(inputDescriptor: 0, outputDescriptor: 1).whenComplete { result in
//                    switch result {
//                    case .success:
//                        // We need to exec a thing.
//                        let execRequest = SSHChannelRequestEvent.ExecRequest(command: self.command, wantReply: false)
//                        print(execRequest)
//                        context.triggerUserOutboundEvent(execRequest).whenFailure { error in
//                            context.fireErrorCaught(error)
//                        }
//                    case .failure(let error):
//                        context.fireErrorCaught(error)
//                    }
//                }
//            }
//        }
    }

    func userInboundEventTriggered(context: ChannelHandlerContext, event: Any) {
        context.fireUserInboundEventTriggered(event)
    }

    func handlerRemoved(context: ChannelHandlerContext) {
        if let promise = self.completePromise {
            self.completePromise = nil
            promise.fail(SSHClientError.commandExecFailed)
        }
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let data = self.unwrapInboundIn(data)

        guard case .byteBuffer(let bytes) = data.data else {
            fatalError("Unexpected read type")
        }
        switch data.type {
        case .channel:
            let text = String(buffer: ByteBuffer(buffer: bytes))
            if let promise = self.completePromise {
                self.completePromise = nil
                promise.succeed(text)
            }
            
            
//            context.writeAndFlush(SSHChannelData(type: .channel, data: .byteBuffer(data)).data, promise: promise)
            // Channel data is forwarded on, the pipe channel will handle it.
            context.fireChannelRead(self.wrapInboundOut(bytes))
            return

        case .stdErr:
            // We just write to stderr directly, pipe channel can't help us here.
            bytes.withUnsafeReadableBytes { str in
                let rc = fwrite(str.baseAddress, 1, str.count, stderr)
                precondition(rc == str.count)
            }

        default:
            fatalError("Unexpected message type")
        }
    }

    func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let data = self.unwrapOutboundIn(data)
        context.write(self.wrapOutboundOut(SSHChannelData(type: .channel, data: .byteBuffer(data))), promise: promise)
    }
}

final class GlueHandler {
    private var partner: GlueHandler?

    private var context: ChannelHandlerContext?

    private var pendingRead: Bool = false

    private init() {}
}

extension GlueHandler {
    static func matchedPair() -> (GlueHandler, GlueHandler) {
        let first = GlueHandler()
        let second = GlueHandler()

        first.partner = second
        second.partner = first

        return (first, second)
    }
}

extension GlueHandler {
    private func partnerWrite(_ data: NIOAny) {
        self.context?.write(data, promise: nil)
    }

    private func partnerFlush() {
        self.context?.flush()
    }

    private func partnerWriteEOF() {
        self.context?.close(mode: .output, promise: nil)
    }

    private func partnerCloseFull() {
        self.context?.close(promise: nil)
    }

    private func partnerBecameWritable() {
        if self.pendingRead {
            self.pendingRead = false
            self.context?.read()
        }
    }

    private var partnerWritable: Bool {
        self.context?.channel.isWritable ?? false
    }
}

extension GlueHandler: ChannelDuplexHandler {
    typealias InboundIn = NIOAny
    typealias OutboundIn = NIOAny
    typealias OutboundOut = NIOAny

    func handlerAdded(context: ChannelHandlerContext) {
        self.context = context

        // It's possible our partner asked if we were writable, before, and we couldn't answer.
        // Consider updating it.
        if context.channel.isWritable {
            self.partner?.partnerBecameWritable()
        }
    }

    func handlerRemoved(context: ChannelHandlerContext) {
        self.context = nil
        self.partner = nil
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        self.partner?.partnerWrite(data)
    }

    func channelReadComplete(context: ChannelHandlerContext) {
        self.partner?.partnerFlush()
    }

    func channelInactive(context: ChannelHandlerContext) {
        self.partner?.partnerCloseFull()
    }

    func userInboundEventTriggered(context: ChannelHandlerContext, event: Any) {
        if let event = event as? ChannelEvent, case .inputClosed = event {
            // We have read EOF.
            self.partner?.partnerWriteEOF()
        }
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        self.partner?.partnerCloseFull()
    }

    func channelWritabilityChanged(context: ChannelHandlerContext) {
        if context.channel.isWritable {
            self.partner?.partnerBecameWritable()
        }
    }

    func read(context: ChannelHandlerContext) {
        if let partner = self.partner, partner.partnerWritable {
            context.read()
        } else {
            self.pendingRead = true
        }
    }
}

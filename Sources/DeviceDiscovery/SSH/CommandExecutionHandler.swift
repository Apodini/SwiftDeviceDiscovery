//
//  File.swift
//  
//
//  Created by Felix Desiderato on 08/07/2021.
//

import Foundation
import NIOSSH
import NIO

class CommandExecutionHandler: ChannelInboundHandler {
    typealias InboundIn = SSHChannelData
    typealias InboundOut = ByteBuffer
    
    let command: String
    let promise: EventLoopPromise<String>?
    
    init(_ command: String, promise: EventLoopPromise<String>?) {
        self.command = command
        self.promise = promise
    }
    
    func handlerAdded(context: ChannelHandlerContext) {
        context.channel.setOption(ChannelOptions.allowRemoteHalfClosure, value: true).whenFailure { error in
            context.fireErrorCaught(error)
        }
    }
    
    func channelActive(context: ChannelHandlerContext) {
        let event = SSHChannelRequestEvent.ExecRequest(command: self.command, wantReply: false)
        context.triggerUserOutboundEvent(event).whenFailure { error in
            context.fireErrorCaught(error)
        }
    }
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let data = self.unwrapInboundIn(data)
        guard case .byteBuffer(let bytes) = data.data else {
            fatalError("Unexpected read type")
        }
        if case .channel = data.type {
            let text = String(buffer: ByteBuffer(buffer: bytes))
            promise?.succeed(text)
            context.fireChannelRead(self.wrapInboundOut(bytes))
        } else if case .stdErr = data.type {
            // We just write to stderr directly, pipe channel can't help us here.
            bytes.withUnsafeReadableBytes { str in
                let rc = fwrite(str.baseAddress, 1, str.count, stderr)
                precondition(rc == str.count)
            }
        } else {}
    }
}

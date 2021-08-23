//
//  ExecutionHandler.swift
//
//
//  Created by Felix Desiderato on 06/07/2021.
//
//
// This code is based on the SwiftNIO SSH project: https://github.com/apple/swift-nio-ssh
//

import NIO
import Dispatch
import NIOSSH
import Logging

final class ExecutionHandler: ChannelDuplexHandler {
    typealias InboundIn = SSHChannelData
    typealias InboundOut = ByteBuffer
    typealias OutboundIn = ByteBuffer
    typealias OutboundOut = SSHChannelData
    
    private let initialShellResponse: String = "Debian GNU/Linux system"
    
    private var responseHandler: ((String) -> Void)?
    
    private var responsePromise: EventLoopPromise<String>?
    
    private var completionPromise: EventLoopPromise<Void>?
    private var nonThrowingCompletionPromise: EventLoopPromise<Bool>?
    
    private var completeOutput: String = ""
    
    init() {}
    
    private func handleResponse(_ response: String) {
        guard !response.contains(initialShellResponse) else {
            return
        }
        
        completeOutput.append(contentsOf: response)
        
        if self.responseHandler != nil {
            self.responseHandler?(response)
        } else {
            print(response)
        }
        
        if response.contains(SSHClient.successCode) {
            nonThrowingCompletionPromise?.succeed(true)
            completionPromise?.succeed(())
        } else if response.contains(SSHClient.failureCode) {
            nonThrowingCompletionPromise?.succeed(false)
            completionPromise?.fail(SSHClientError.executionFailed)
        }
        
        //invalidate responsehandler afterwards, as responseHandler is request specific
        self.responseHandler = nil
    }
    
    func handlerAdded(context: ChannelHandlerContext) {
        context.channel.setOption(ChannelOptions.allowRemoteHalfClosure, value: true).whenFailure { error in
            context.fireErrorCaught(error)
        }
    }
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let unwrappedData = self.unwrapInboundIn(data)
        guard case let .byteBuffer(buffer) = unwrappedData.data else {
            fatalError("wrong type")
        }
        let response = String(buffer: buffer)
        handleResponse(response)

        context.fireChannelRead(data)
    }
    
    func userInboundEventTriggered(context: ChannelHandlerContext, event: Any) {
        context.fireUserInboundEventTriggered(event)
    }
    
    func triggerUserOutboundEvent(context: ChannelHandlerContext, event: Any, promise: EventLoopPromise<Void>?) {
        switch event {
        case let event as SSHChannelRequestEvent.ShellRequest:
            context.triggerUserOutboundEvent(event, promise: promise)
        case let event as (ByteBuffer, ((String) -> Void)?):
            self.completionPromise = promise
            self.responseHandler = event.1
            self.write(context: context, data: self.wrapInboundOut(event.0), promise: nil)
        case let event as (ByteBuffer, ((String) -> Void)?, EventLoopPromise<Bool>):
            self.responseHandler = event.1
            self.nonThrowingCompletionPromise = event.2
            self.write(context: context, data: self.wrapInboundOut(event.0), promise: nil)
        case let event as ByteBuffer:
            self.completionPromise = promise
            self.write(context: context, data: self.wrapInboundOut(event), promise: nil)
        default:
            context.triggerUserOutboundEvent(event, promise: promise)
        }
    }
    
    func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let data = self.unwrapOutboundIn(data)
        context.writeAndFlush(self.wrapOutboundOut(SSHChannelData(type: .channel, data: .byteBuffer(data))), promise: promise)
    }
}

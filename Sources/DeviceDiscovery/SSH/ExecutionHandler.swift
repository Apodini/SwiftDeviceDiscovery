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
    
    init() {}
    
    private func handleResponse(_ response: String) {
        guard !response.contains(initialShellResponse) else {
            return
        }
        
        if let responseH = self.responseHandler {
            responseH(response)
        } else if self.responsePromise != nil {
            responsePromise?.succeed(response)
        } else {
            print(response)
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
        print(event)
        context.fireUserInboundEventTriggered(event)
    }
    
    func triggerUserOutboundEvent(context: ChannelHandlerContext, event: Any, promise: EventLoopPromise<Void>?) {
        switch event {
        case let event as SSHChannelRequestEvent.ShellRequest:
            context.triggerUserOutboundEvent(event, promise: promise)
        case let event as (ByteBuffer, ((String) -> Void)?):
            self.responseHandler = event.1
            self.write(context: context, data: self.wrapInboundOut(event.0), promise: promise)
        case let event as (ByteBuffer, EventLoopPromise<String>):
            self.responsePromise = event.1
            self.write(context: context, data: self.wrapInboundOut(event.0), promise: promise)
        case let event as ByteBuffer:
            self.write(context: context, data: self.wrapInboundOut(event), promise: promise)
        default:
            context.triggerUserOutboundEvent(event, promise: promise)
        }
    }
    
    func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let data = self.unwrapOutboundIn(data)
        context.writeAndFlush(self.wrapOutboundOut(SSHChannelData(type: .channel, data: .byteBuffer(data))), promise: promise)
    }
}

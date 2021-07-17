import NIO
import Dispatch
import NIOSSH


public final class ExecutionHandler: ChannelDuplexHandler {
    public typealias InboundIn = SSHChannelData
    public typealias InboundOut = ByteBuffer
    public typealias OutboundIn = ByteBuffer
    public typealias OutboundOut = SSHChannelData
    
    private var responseHandler: ((String, Int32) -> Void)?
    private var intermediateResult: String = ""
    private var completionPromise: EventLoopPromise<Void>?
    private var exitStatus: Int32?
    
    public init() {}
    
    public func handlerAdded(context: ChannelHandlerContext) {
        context.channel.setOption(ChannelOptions.allowRemoteHalfClosure, value: true).whenFailure { error in
            context.fireErrorCaught(error)
        }
    }
    
    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let unwrappedData = self.unwrapInboundIn(data)
        guard case let .byteBuffer(buffer) = unwrappedData.data else {
            fatalError("wrong type")
        }
        intermediateResult.append(String(buffer: buffer))
        context.fireChannelRead(data)
    }
    
    public func channelInactive(context: ChannelHandlerContext) {
        print(#function)
        guard let exitStatus = exitStatus, exitStatus == EXIT_SUCCESS else {
            completionPromise?.fail(SSHError.commandExecFailed(intermediateResult))
            self.responseHandler?(intermediateResult, EXIT_FAILURE)
            return
        }
        completionPromise?.succeed(())
        responseHandler?(intermediateResult, exitStatus)
    }
    
    public func userInboundEventTriggered(context: ChannelHandlerContext, event: Any) {
        switch event {
        case let event as SSHChannelRequestEvent.ExitStatus:
            self.exitStatus = Int32(event.exitStatus)
            context.fireUserInboundEventTriggered(event)
        default:
            context.fireUserInboundEventTriggered(event)
        }
    }

    public func triggerUserOutboundEvent(context: ChannelHandlerContext, event: Any, promise: EventLoopPromise<Void>?) {
        guard let (buffer, responseHandler) = event as? (ByteBuffer, ((String, Int32) -> Void)?) else {
            promise?.fail(SSHError.invalidData)
            return
        }
        self.completionPromise = promise
        self.responseHandler = responseHandler
        let _ = context.triggerUserOutboundEvent(SSHChannelRequestEvent.ExecRequest(command: String(buffer: buffer), wantReply: false))
    }
}

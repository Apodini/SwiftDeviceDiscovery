//
//  ErrorHandler.swift
//
//  Created by Felix Desiderato on 08/07/2021.
//
// This code is based on the SwiftNIO SSH project: https://github.com/apple/swift-nio-ssh
//

import Foundation
import NIOSSH
import NIO
import Logging

class ErrorHandler: ChannelInboundHandler {
    typealias InboundIn = Any
    
    func errorCaught(context: ChannelHandlerContext, error: Error) {
        SSHClient.logger.error("Error caught during ssh execution: \(error)")
        _ = context.close()
    }
}

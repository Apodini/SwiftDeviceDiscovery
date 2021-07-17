//
//  ErrorHandler.swift
//  
//
//  Created by Felix Desiderato on 08/07/2021.
//

import Foundation
import NIOSSH
import NIO
import Logging

class ErrorHandler: ChannelInboundHandler {
    typealias InboundIn = Any
    
    func errorCaught(context: ChannelHandlerContext, error: Error) {
        SSHClient.logger.error("Error caught during ssh execution: \(error)")
        let _ = context.close()
    }
}

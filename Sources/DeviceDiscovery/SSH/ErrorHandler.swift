//
// This source file is part of the Apodini open source project
//
// SPDX-FileCopyrightText: 2019-2021 Paul Schmiedmayer and the Apodini project authors (see CONTRIBUTORS.md) <paul.schmiedmayer@tum.de>
//
// SPDX-License-Identifier: MIT
//
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

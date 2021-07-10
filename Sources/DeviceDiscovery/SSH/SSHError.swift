//
//  File.swift
//  
//
//  Created by Felix Desiderato on 08/07/2021.
//

import Foundation

enum SSHError: Swift.Error {
    case commandExecFailed
    case invalidChannelType
    case invalidData
    case channelNotFound(msg: String)
}


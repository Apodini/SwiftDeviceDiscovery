//
//  File.swift
//  
//
//  Created by Felix Desiderato on 08/07/2021.
//

import Foundation

enum SSHError: Swift.Error {
    case commandExecFailed(String)
    case invalidChannelType
    case invalidData
    case channelNotFound(msg: String)
    case failedSuccessfulExecution(String)
    case remoteDirAlreadyExists
    case postDiscoveryActionFailed(ActionIdentifier)
}


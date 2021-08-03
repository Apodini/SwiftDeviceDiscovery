//
//  AcceptAllKeysDelegate.swift
//  
//
//  Created by Felix Desiderato on 08/07/2021.
//
// This code is based on the SwiftNIO SSH project: https://github.com/apple/swift-nio-ssh
//

import Foundation
import NIO
import NIOSSH

class AcceptAllKeysDelegate: NIOSSHClientServerAuthenticationDelegate {
    func validateHostKey(hostKey: NIOSSHPublicKey, validationCompletePromise: EventLoopPromise<Void>) {
        // Do not replicate this in your own code: validate host keys! This is a
        // choice made for expedience, not for any other reason.
        validationCompletePromise.succeed(())
    }
}

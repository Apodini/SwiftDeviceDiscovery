//
//  InteractivePasswordPromptDelegate.swift
//  
//
//  Created by Felix Desiderato on 06/07/2021.
//

import Dispatch
import Foundation
import NIO
import NIOSSH

/// A client user auth delegate that provides an interactive prompt for password-based user auth.
public struct InteractivePasswordPromptDelegate: NIOSSHClientUserAuthenticationDelegate {
    let username: String
    let password: String

    public func nextAuthenticationType(availableMethods: NIOSSHAvailableUserAuthenticationMethods, nextChallengePromise: EventLoopPromise<NIOSSHUserAuthenticationOffer?>) {
        guard availableMethods.contains(.password) else {
            print("Error: password auth not supported")
            nextChallengePromise.fail(SSHClientError.passwordAuthenticationNotSupported)
            return
        }
        nextChallengePromise.succeed(NIOSSHUserAuthenticationOffer(username: self.username, serviceName: "", offer: .password(.init(password: self.password))))
    }
}

public enum SSHClientError: Swift.Error {
    case passwordAuthenticationNotSupported
    case invalidChannelType
}

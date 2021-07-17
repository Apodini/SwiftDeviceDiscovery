//
//  File.swift
//  
//
//  Created by Felix Desiderato on 06/07/2021.
//

import Dispatch
import Foundation
import NIO
import NIOSSH

/// A client user auth delegate that provides an interactive prompt for password-based user auth.
public class InteractivePasswordPromptDelegate: NIOSSHClientUserAuthenticationDelegate {
    private let queue: DispatchQueue

    private var username: String?

    private var password: String?

    public init(username: String?, password: String?) {
        self.queue = DispatchQueue(label: "io.swiftnio.ssh.InteractivePasswordPromptDelegate")
        self.username = username
        self.password = password
    }

    public func nextAuthenticationType(availableMethods: NIOSSHAvailableUserAuthenticationMethods, nextChallengePromise: EventLoopPromise<NIOSSHUserAuthenticationOffer?>) {
        guard availableMethods.contains(.password) else {
            print("Error: password auth not supported")
            nextChallengePromise.fail(SSHClientError.passwordAuthenticationNotSupported)
            return
        }

        self.queue.async {
            if self.username == nil {
                print("Username: ", terminator: "")
                self.username = readLine() ?? ""
            }

            if self.password == nil {
                #if os(Windows)
                print("Password: ", terminator: "")
                self.password = readLine() ?? ""
                #else
                self.password = String(cString: getpass("Password: "))
                #endif
            }

            nextChallengePromise.succeed(NIOSSHUserAuthenticationOffer(username: self.username!, serviceName: "", offer: .password(.init(password: self.password!))))
        }
    }
}

public enum SSHClientError: Swift.Error {
    case passwordAuthenticationNotSupported
    case commandExecFailed
    case invalidChannelType
    case invalidData
    case rsyncLocalDirNotFound
    case remoteDirAlreadyExists
}

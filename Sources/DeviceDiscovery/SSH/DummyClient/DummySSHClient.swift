//
//  File.swift
//  
//
//  Created by Felix Desiderato on 12/07/2021.
//

import Foundation
import Shout
import Logging

public class DummySSHClient {
    public typealias CommandResult = (Int32?, String)
    
    var session: SSH?
    
    let logger: Logger
    
    
    public init(logger: Logger) {
        self.logger = logger
    }
    
    public func initialize(host: String, username: String, password: String) throws {
        self.session = try SSH(host: host)
        try self.session?.authenticate(username: username, password: password)
    }
    
    public func execute(_ command: String, silent: Bool = false) throws -> CommandResult {
        guard let result = try self.session?.capture(command) else {
            throw DummySSHError.resultWasNil
        }
        if !silent {
            logger.info("\(result.output)")
        }
        return result
    }
}

public enum DummySSHError: Swift.Error {
    case resultWasNil
}

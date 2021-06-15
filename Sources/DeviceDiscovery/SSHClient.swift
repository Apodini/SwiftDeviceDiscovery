//
//  SSHClient.swift
//  DeviceDiscovery
//
//  Created by Felix Desiderato on 31.05.21.
//

import Foundation
import Shout


protocol SSHable {
    var username: String { get }
    var password: String { get }
}


class SSHClient {
    var client: SSHable?
    var session: SSH?
    
    init(_ client: SSHable & DiscoverableObject) throws {
        self.client = client
        if let address = client.ipAddress {
            do {
                try self.session = SSH(host: address)
                try self.session?.authenticate(username: client.username, password: client.password)
            } catch {
                print(error)
            }
        }
    }

    func assertSuccessfulExecution(_ commands: [String], silent: Bool = true) throws {
        for command in commands {
            let result = try session?.execute(command, silent: silent)
            guard result == EXIT_SUCCESS else { fatalError("Command \(command) failed during execution")}
        }
    }
    
    @discardableResult
    func execute(_ command: String, silent: Bool = true) throws -> Int32 {
        let result = try session?.execute(command, silent: silent)
        print(result)
        return result ?? .max
    }
    
    func execute(_ command: String, onCompletion: ((Bool) -> Void)) throws {
        let result = try session?.execute(command, silent: true)
        onCompletion(result == EXIT_SUCCESS)
    }
    
    func sendFile(_ pathToFile: URL, remotePath: String, onCompletion: ((Bool) -> Void)) throws {
        let result = try session?.sendFile(localURL: pathToFile, remotePath: remotePath)
        onCompletion(result == EXIT_SUCCESS)
    }
    
    func copyDir(_ pathToDir: URL, remotePath: String, createDirIfNecessary: Bool, onCompletion: ((Bool) -> Void)) throws {
        let stfp = try session?.openSftp()
        if createDirIfNecessary {
            try session?.execute("sudo mkdir " + remotePath)
        }
        
        
        do {
            try stfp?.listFiles(in: "/usr")
        } catch {
            print(error)
            fatalError(error.localizedDescription)
        }
//        try stfp?.upload(localURL: pathToDir, remotePath: remotePath)
        onCompletion(true)
    }
}

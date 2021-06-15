//
//  Task.swift
//  DeviceDiscovery
//
//  Created by Felix Desiderato on 08.06.21.
//

import Foundation
import Network

class Task {
    
    private var process: Process
    
    let stdin = Pipe()
    let stdout = Pipe()
    let stderr = Pipe()
    
    init(_ arguments: [String], lauchPath: String = "/usr/bin/env") {
        process = Process()
        process.launchPath = lauchPath
        process.arguments = arguments
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = stderr
    }

    @discardableResult
    func run() -> Int32 {
        process.launch()
        process.waitUntilExit()
        print(stderr.readablePipeContent())
        print(stdout.readablePipeContent())
        return process.terminationStatus
    }
}

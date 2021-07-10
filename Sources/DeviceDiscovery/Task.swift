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
        process.executableURL = Self._findExecutable("ssh")
        process.arguments = arguments
        stdin.fileHandleForWriting.write("rasp\n".data(using: .utf8)!)
        print(stdin.debugDescription)
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = stderr
        
//        print(process.)
    }

    @discardableResult
    func run() -> Int32 {
        try! process.run()
//        process.waitUntilExit()
        print(stderr.readablePipeContent())
        print(stdout.readablePipeContent())
        return process.terminationStatus
    }
    
    public static func findExecutable(named binaryName: String) -> URL? {
        guard let searchPaths = ProcessInfo.processInfo.environment["PATH"]?.components(separatedBy: ":") else {
            return nil
        }
        for searchPath in searchPaths {
            let executableUrl = URL(fileURLWithPath: searchPath, isDirectory: true)
                .appendingPathComponent(binaryName, isDirectory: false)
            if FileManager.default.fileExists(atPath: executableUrl.path) {
                return executableUrl
            }
        }
        return nil
    }
    
    private static func _findExecutable(_ name: String) -> URL {
        guard let url = Task.findExecutable(named: name) else {
            fatalError("Unable to find executable '\(name)'")
        }
        return url
    }
}

extension Pipe {
    func readablePipeContent() -> String? {
        let theTaskData = fileHandleForReading.readDataToEndOfFile()
        let stringResult = String(data: theTaskData, encoding: .utf8)
        return stringResult
    }
}


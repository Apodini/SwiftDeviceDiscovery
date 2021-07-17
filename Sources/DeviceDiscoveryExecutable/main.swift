//
//  File.swift
//  
//
//  Created by Felix Desiderato on 11/07/2021.
//

import Foundation
import DeviceDiscovery
import NIO
import NIOSSH
//

class Tester {
    
    static func main() throws {
        //Do something
        let discovery = DeviceDiscovery(DeviceIdentifier("_workstation._tcp."))
        discovery.configuration = [
            .username: "pi",
            .password: "rasp",
            .runPostActions: true
        ]
        discovery.onConfiguration = { device, config in
            print(device)
            if let _ = config.typedValue(for: .runPostActions, to: Bool.self) {
                print("hello")
            }
        }
        let results = try discovery.run(1)
        let client = try SSHClient(username: "pi", password: "rasp", ipAdress: "192.168.2.117")
        let remoteURL = URL(string: "/usr/deployment")
        try client.fileManager.createDir(on: remoteURL!)
    }
    
}
try Tester.main()


//
//let (reason, output) = try client.fileManager.copyResources(from: URL(string: "/Users/felice/Downloads/ENS-Englisch")!, to: URL(string: "/usr/deployment")!)
//print((reason, output))





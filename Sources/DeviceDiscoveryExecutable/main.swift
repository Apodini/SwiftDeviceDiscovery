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
        
        let _ = try discovery.run(1)
    }
    
}
try Tester.main()

//
//  File.swift
//  
//
//  Created by Felix Desiderato on 11/07/2021.
//

import Foundation
import DeviceDiscovery

struct Executable {
    static func main() throws {
        let piId = DeviceIdentifier("_workstation._tcp.")
        let discovery = DeviceDiscovery(piId)
        let results = try discovery.run().wait()
        print(results)
        
    }
}

try Executable.main()

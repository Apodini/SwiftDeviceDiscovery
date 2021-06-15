import Foundation
import ArgumentParser
import Network
import Shout
import Logging

struct Test: ParsableCommand {
    
    func run() throws {
        let discovery = DeviceDiscovery()
        try discovery.execute(5)
    }
    
}

Test.main()

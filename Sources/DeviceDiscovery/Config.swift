//
//  Config.swift
//  DeviceDiscovery
//
//  Created by Felix Desiderato on 25.05.21.
//

import Foundation

struct CONFIG {
    static let deviceType: String = "_workstation._tcp."
    static let domain: String = "local."
}


struct COMMANDS {
    struct Installation {
        static let dockerCompose: String = "sudo curl -L \"https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)\" -o /usr/local/bin/docker-compose"
    }
}

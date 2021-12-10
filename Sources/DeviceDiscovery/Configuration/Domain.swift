//
// This source file is part of the Apodini open source project
//
// SPDX-FileCopyrightText: 2019-2021 Paul Schmiedmayer and the Apodini project authors (see CONTRIBUTORS.md) <paul.schmiedmayer@tum.de>
//
// SPDX-License-Identifier: MIT
//

import Foundation

/// Used to set the domain in which the `DeviceDiscovery` is looking for devices.
public enum Domain {
    /// The local domain.
    case local
    /// A custom domain.
    case custom(String)
    
    /// Returns a string representation of the domain.
    var value: String {
        switch self {
        case .local:
            return "local."
        case .custom(let dom):
            return dom
        }
    }
}

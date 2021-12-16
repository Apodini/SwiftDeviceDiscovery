//
// This source file is part of the Apodini open source project
//
// SPDX-FileCopyrightText: 2019-2021 Paul Schmiedmayer and the Apodini project authors (see CONTRIBUTORS.md) <paul.schmiedmayer@tum.de>
//
// SPDX-License-Identifier: MIT
//

import Foundation

/// An Address resolver that tries to resolve the local ip address from the host and domain.
public enum IPAddressResolver {
    static func resolveIPAdress(_ host: String?, domain: String) -> String? {
        guard let host = host else {
            return nil
        }
        // Get something like [host].[domain]
        let hostName = host + "." + domain.trimmingCharacters(in: .punctuationCharacters)
        
        var res: UnsafeMutablePointer<addrinfo>?
        let error = getaddrinfo(hostName, nil, nil, &res)
        guard error == 0 else {
            print(error)
            return nil
        }
        defer {
            freeaddrinfo(res)
        }
        var addresses = [Data]()
        // swiftlint:disable:next force_unwrapping
        for addr in sequence(first: res!, next: { $0.pointee.ai_next }) {
            addresses.append(Data(bytes: addr.pointee.ai_addr, count: Int(addr.pointee.ai_addrlen)))
        }
        
        var ipname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        for data in addresses {
            data.withUnsafeBytes { (pointer: UnsafeRawBufferPointer) -> Void in
                let sockaddrPtr = pointer.bindMemory(to: sockaddr.self)
                guard let unsafePtr = sockaddrPtr.baseAddress else {
                    return
                }
                guard getnameinfo(unsafePtr, socklen_t(data.count), &ipname, socklen_t(ipname.count), nil, 0, NI_NUMERICHOST) == 0 else {
                    return
                }
            }
            let ipAddress = String(cString: ipname)
            if ipAddress.isIPv4() {
                return ipAddress
            }
        }
        return nil
    }
}

extension String {
    func isIPv4() -> Bool {
        var sin = sockaddr_in()
        return self.withCString { cstring in
            inet_pton(AF_INET, cstring, &sin.sin_addr)
        } == 1
    }
}

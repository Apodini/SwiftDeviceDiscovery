//
//  IPAddressResolver.swift
//  DeviceDiscovery
//
//  Created by Felix Desiderato on 25.05.21.
//

import Foundation


protocol NetworkAddress {
    static var family: Int32 { get }
    static var maxStringLength: Int32 { get }
}
extension in_addr: NetworkAddress {
    static let family = AF_INET
    static let maxStringLength = INET_ADDRSTRLEN
}
extension in6_addr: NetworkAddress {
    static let family = AF_INET6
    static let maxStringLength = INET6_ADDRSTRLEN
}

extension String {
    init<A: NetworkAddress>(address: A) {
        // allocate a temporary buffer large enough to hold the string
        var buf = ContiguousArray<Int8>(repeating: 0, count: Int(A.maxStringLength))
        self = withUnsafePointer(to: address) { rawAddr in
            buf.withUnsafeMutableBufferPointer {
                String(cString: inet_ntop(A.family, rawAddr, $0.baseAddress, UInt32($0.count)))
            }
        }
    }
}

internal struct IPAddressResolver {
    var hostName: String
    var ipv4Address: String?
    var ipv6Address: String?
    
    init(_ hostName: String) {
        self.hostName = hostName
        resolveIPAdress(hostName)
    }
    
    private mutating func resolveIPAdress(_ host: String) {
        var streamError = CFStreamError()
        
        let cfHost = CFHostCreateWithName(nil, host as CFString).takeRetainedValue()
        let status = CFHostStartInfoResolution(cfHost, .addresses, &streamError)
        
        if status {
            var success: DarwinBoolean = false
            guard let addresses = CFHostGetAddressing(cfHost, &success)?.takeUnretainedValue() as NSArray? else {
                print("failed to retrieve addresses")
                return
            }
            
            for address in addresses {
                let addressData = address as! NSData // swiftlint:disable:this force_cast
                let addrin = addressData.bytes.assumingMemoryBound(to: sockaddr.self).pointee
                if addressData.length >= MemoryLayout<sockaddr>.size && addrin.sa_family == UInt8(AF_INET) {
                    addressToString(data: addressData as Data)
                }
            }
        }
    }
    
    private mutating func addressToString(data: Data) {
        data.withUnsafeBytes {
            let family = $0.baseAddress.unsafelyUnwrapped.assumingMemoryBound(to: sockaddr_storage.self).pointee.ss_family
            if family == numericCast(AF_INET) {
                ipv4Address = String(address: $0.baseAddress.unsafelyUnwrapped.assumingMemoryBound(to: sockaddr_in.self).pointee.sin_addr)
            } else if family == numericCast(AF_INET6) {
                ipv6Address = String(address: $0.baseAddress.unsafelyUnwrapped.assumingMemoryBound(to: sockaddr_in6.self).pointee.sin6_addr)
            }
        }
    }
}

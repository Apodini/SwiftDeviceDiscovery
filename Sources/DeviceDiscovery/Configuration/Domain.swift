//
//  File.swift
//  
//
//  Created by Felix Desiderato on 08/07/2021.
//

import Foundation

public enum Domain {
    case local
    case custom(String)
    
    var value: String {
        switch self {
        case .local:
            return "local."
        case .custom(let dom):
            return dom
        }
    }
}

//
//  SyncCommand.swift
//  VirtualSet
//
//  Created by Reza on 11/11/21.
//  Copyright © 2021 Dynamic Stacks LTD. All rights reserved.
//

import Foundation

enum SyncCommand: String {
    case status
    case record
    case elapsed
    case stop
    case width
    case height
    case dimension
    case videoSaved
    
    enum Status: Int {
        case preparing
        case viewing
        case recording
    }
}

//
//  VSSession+WatchSessionDataSource.swift
//  VirtualSet
//
//  Created by Reza on 11/12/21.
//  Copyright © 2021 Dynamic Stacks LTD. All rights reserved.
//

import Foundation

extension VSSession: WatchSessionDataSource {
    func currentState() -> SessionState {
        return state
    }
}

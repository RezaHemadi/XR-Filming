//
//  VSSession.swift
//  VirtualSet
//
//  Created by Reza on 9/3/21.
//

import Foundation
import Combine

/// - Tag: Virtual Set Session Class
final class VSSession: ObservableObject {
    @Published var state: State = .initializing
}

// MARK: - Types
extension VSSession {
    enum State {
        case initializing
        case pickingSet
        case inProgress
    }
}

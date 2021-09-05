//
//  VSSession.swift
//  VirtualSet
//
//  Created by Reza on 9/3/21.
//

import Foundation
import Combine
import RealityKit
import os.signpost

/// - Tag: Virtual Set Session Class
final class VSSession: NSObject, ObservableObject {
    // MARK: - Properties
    
    /// Reflects the current state of the user experience to update the user interface accordingly
    @Published var state: State = .initializing
    
    /// Keep track of recording status
    @Published var isRecording: Bool = false
    
    /// View That Renders AR Content
    var arView: ARView? {
        didSet {
            guard oldValue != arView else { return }
            
            arView?.session.delegate = self
        }
    }
    
    /// determine whether AR Session should attempt relocalization
    var shouldAttemptRelocalization: Bool {
        true
    }
}

// MARK: - Types
extension VSSession {
    enum State {
        case initializing
        case pickingSet
        case exploringScene
    }
}

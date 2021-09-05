//
//  VSSession+ARSessionDelegate.swift
//  VirtualSet
//
//  Created by Reza on 9/3/21.
//

import Foundation
import RealityKit
import ARKit
import os.signpost

/// - Tag: Respond to world tracking changes in app
extension VSSession: ARSessionDelegate {
    func sessionWasInterrupted(_ session: ARSession) {
        os_log(.info, "session was interrupted")
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        os_log(.info, "session interruption ended")
    }
    
    func sessionShouldAttemptRelocalization(_ session: ARSession) -> Bool {
        os_log(.info, "session should attempt relocalization?")
        
        return shouldAttemptRelocalization
    }
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        os_log(.info, "camera did change tracking state to: %s", "\(camera.trackingState)")
        switch camera.trackingState {
        case .notAvailable:
            isTrackingNormal = false
        case .limited(let _):
            isTrackingNormal = false
            if state == .initializing {
                state = .pickingSet
            }
        case .normal:
            isTrackingNormal = true
        }
    }
    
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        
    }
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        
    }
    
    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        if !frame.anchors.compactMap({$0 as? ARPlaneAnchor}).isEmpty {
            surfaceDetected = true
        } else {
            surfaceDetected = false
        }
    }
}

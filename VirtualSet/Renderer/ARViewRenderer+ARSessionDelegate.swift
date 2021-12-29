//
//  ARViewRenderer+ARSessionDelegate.swift
//  VirtualSet
//
//  Created by Reza on 12/22/21.
//  Copyright © 2021 Dynamic Stacks LTD. All rights reserved.
//

import Foundation
import ARKit
import os.signpost

extension ARViewRenderer: ARSessionDelegate {
    func sessionWasInterrupted(_ session: ARSession) {
        os_log(.info, "session was interrupted")
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        for anchor in frame.anchors {
            if let planeAnchor = anchor as? ARPlaneAnchor {
                let width = planeAnchor.extent.x
                let height = planeAnchor.extent.z
                
                if !width.isLess(than: 1.5) && !height.isLess(than: 1.5) {
                    self.floorDetected = true
                    return
                }
            }
        }
    }
    
    func sessionShouldAttemptRelocalization(_ session: ARSession) -> Bool {
        return true
    }
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        switch camera.trackingState {
        case .notAvailable:
            break
        case .limited(_):
            self.isTrackingNormal = false
        case .normal:
            self.isTrackingNormal = true
        }
    }
}

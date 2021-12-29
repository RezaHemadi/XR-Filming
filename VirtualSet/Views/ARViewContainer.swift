//
//  ARViewContainer.swift
//  VirtualSet
//
//  Created by Reza on 9/3/21.
//

import SwiftUI
import RealityKit
import ARKit

/// - Tag: ARViewContainer Structure to interface SwiftUI content view with UIKit
struct ARViewContainer {
    // MARK: - Properties
    var session: VSSession
    
    // MARK: - Coordinator that manages interfacing with SwiftUI
    class Coordinator: NSObject, ARCoachingOverlayViewDelegate {
        // MARK: - Properties
        var parent: ARViewContainer
        
        init(_ arViewContainer: ARViewContainer) {
            parent = arViewContainer
        }
        
        func coachingOverlayViewDidRequestSessionReset(_ coachingOverlayView: ARCoachingOverlayView) {
            parent.session.resetTracking()
        }
    }
}

// MARK: - UIViewRepresentable Conformance
extension ARViewContainer: UIViewRepresentable {
    
    func makeUIView(context: Context) -> ARView {
        
        #if targetEnvironment(simulator)
        let arView = ARView(frame: .zero)
        arView.cameraMode = .nonAR
        
        let cameraEntity = PerspectiveCamera()
        cameraEntity.camera.fieldOfViewInDegrees = 60.0
        let cameraAnchor = AnchorEntity(world: .zero)
        cameraAnchor.addChild(cameraEntity)
        arView.scene.addAnchor(cameraAnchor)
        
        let skyboxName = "aerodynamics_workshop_4k" // The .exr or .hdr file
        let skyboxResource = try! EnvironmentResource.load(named: skyboxName)
        arView.environment.lighting.resource = skyboxResource
        arView.environment.background = .skybox(skyboxResource)
        
        session.arView = arView
        
        return arView
        
        #else
        
        let arView = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false)
         
        // Capture the instantiated arView to access when app state changes
        session.arView = arView
         
        return arView
        
        #endif
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
}

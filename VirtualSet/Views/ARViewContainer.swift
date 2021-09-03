//
//  ARViewContainer.swift
//  VirtualSet
//
//  Created by Reza on 9/3/21.
//

import SwiftUI
import RealityKit

/// - Tag: ARViewContainer Structure to interface SwiftUI content view with UIKit
struct ARViewContainer {
    // MARK: - Properties
    var session: VSSession
    
    // MARK: - Coordinator that manages interfacing with SwiftUI
    class Coordinator: NSObject {
        // MARK: - Properties
        var parent: ARViewContainer
        
        init(_ arViewContainer: ARViewContainer) {
            parent = arViewContainer
        }
    }
}

// MARK: - UIViewRepresentable Conformance
extension ARViewContainer: UIViewRepresentable {
    
    func makeUIView(context: Context) -> ARView {
        
        let arView = ARView(frame: .zero)
        
        // Capture the instantiated arView to access when app state changes
        session.arView = arView
        
        // Load the "Box" scene from the "Experience" Reality File
        let boxAnchor = try! Experience.loadBox()
        
        // Add the box anchor to the scene
        arView.scene.anchors.append(boxAnchor)
        
        return arView
        
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
}

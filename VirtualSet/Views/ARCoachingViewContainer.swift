//
//  ARCoachingViewContainer.swift
//  VirtualSet
//
//  Created by Reza on 9/5/21.
//

import Foundation
import SwiftUI
import ARKit
import os.signpost

struct ARCoachingViewContainer {
    var session: VSSession
    
    class Coordinator: NSObject {
        var parent: ARCoachingViewContainer
        
        init(_ coachingViewContainer: ARCoachingViewContainer) {
            self.parent = coachingViewContainer
        }
    }
}

extension ARCoachingViewContainer: UIViewRepresentable {
    func makeUIView(context: Context) -> ARCoachingOverlayView {
        let coachingOverlay = ARCoachingOverlayView()
        coachingOverlay.activatesAutomatically = false
        coachingOverlay.delegate = session
        session.coachingOverlay = coachingOverlay
        
        return coachingOverlay
    }
    
    func updateUIView(_ uiView: ARCoachingOverlayView, context: Context) {
        
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }
}

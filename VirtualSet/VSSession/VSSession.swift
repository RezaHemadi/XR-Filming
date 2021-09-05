//
//  VSSession.swift
//  VirtualSet
//
//  Created by Reza on 9/3/21.
//

import Foundation
import Combine
import RealityKit
import ARKit
import os.signpost
import SwiftUI

/// - Tag: Virtual Set Session Class
final class VSSession: NSObject, ObservableObject {
    // MARK: - Properties
    
    /// Reflects the current state of the user experience to update the user interface accordingly
    @Published var state: State = .initializing {
        didSet {
            guard oldValue != state else { return }
            
            configureARSession(state)
        }
    }
    
    /// Keep track of recording status
    @Published var isRecording: Bool = false
    
    /// View That Renders AR Content
    var arView: ARView? {
        didSet {
            guard oldValue != arView else { return }
            
            arView?.session.delegate = self
            configureARSession(state)
            coachingOverlay = ARCoachingViewContainer(session: self)
        }
    }
    
    /// Array of Scenes included in the bundle
    @Published var bundleSets = [VirtualSet]()
    
    /// determine whether AR Session should attempt relocalization
    var shouldAttemptRelocalization: Bool {
        true
    }
    
    var coachingOverlay: ARCoachingViewContainer?
    var uiCoachingView: ARCoachingOverlayView?
    var surfaceDetected: Bool = false {
        didSet {
            os_log(.info, "surface detected: %s", "\(surfaceDetected)")
            shouldShowCoachingOverlay = !(surfaceDetected && isTrackingNormal)
        }
    }
    var isTrackingNormal: Bool = false {
        didSet {
            os_log(.info, "is tracking normal: %s", "\(isTrackingNormal)")
            shouldShowCoachingOverlay = !(surfaceDetected && isTrackingNormal)
        }
    }
    
    @Published var shouldShowCoachingOverlay: Bool = false {
        didSet {
            guard oldValue != shouldShowCoachingOverlay else { return }
            
            os_log(.info, "should show coaching overlay: %s", "\(shouldShowCoachingOverlay)")
            
            uiCoachingView?.setActive(shouldShowCoachingOverlay, animated: true)
        }
    }
    
    // MARK: - Initializatin
    override init() {
        super.init()
        
        loadBundleScenes()
    }
    
    // MARK: - Methods
    private func loadBundleScenes() {
        Experience.loadSceneOneAsync { result in
            switch result {
            case .success(let sceneOne):
                let set = VirtualSet(image: Image("SceneOne"), set: sceneOne)
                self.bundleSets.append(set)
                
            case .failure(let error):
                os_log(.error, "error loading scene one from app bundle: %s", "\(error.localizedDescription)")
                return
            }
        }
    }
    
    private func configureARSession(_ state: State) {
        guard let session = arView?.session else { return }
        
        let configuration = ARWorldTrackingConfiguration()
        let options: ARSession.RunOptions = []
        
        switch state {
        case .initializing, .pickingSet:
            configuration.planeDetection = [.horizontal]
            session.run(configuration, options: options)
        case .exploringScene:
            configuration.frameSemantics = .personSegmentationWithDepth
            session.run(configuration, options: options)
        }
    }
    
    // MARK: - User Interaction
    func userDidPickSet(_ set: VirtualSet) {
        state = .exploringScene
        
        arView!.scene.addAnchor(set.set)
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

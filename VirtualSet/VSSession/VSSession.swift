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

typealias Stage = Entity & HasAnchoring

/// - Tag: Virtual Set Session Class
final class VSSession: NSObject, ObservableObject {
    // MARK: - Properties
    var sceneLoader: SceneLoader
    var recorder: Recorder!
    
    /// Reflects the current state of the user experience to update the user interface accordingly
    @Published var state: State = .initializing {
        didSet {
            configureARSession(state)
            
            switch state {
            case .initializing:
                break
            case .pickingSet:
                if oldValue == .exploringScene {
                    // User Wants To Change The Scene
                    if let arView = self.arView, let current = activeStage {
                        arView.scene.removeAnchor(current)
                        activeStage = nil
                    }
                }
            case .exploringScene:
                recorder = Recorder(view: arView!, isRecording: $isRecording)
            }
        }
    }
    
    /// Keep track of recording status
    @Published var isRecording: Bool = false
    
    private var streams = [AnyCancellable]()
    
    /// View That Renders AR Content
    var arView: ARView? {
        didSet {
            guard oldValue != arView else { return }
            
            arView?.session.delegate = self
            configureARSession(state)
            coachingOverlay = ARCoachingViewContainer(session: self)
        }
    }
    
    /// determine whether AR Session should attempt relocalization
    var shouldAttemptRelocalization: Bool {
        true
    }
    
    var coachingOverlay: ARCoachingViewContainer?
    var uiCoachingView: ARCoachingOverlayView?
    var surfaceDetected: Bool = false {
        didSet {
            guard oldValue != surfaceDetected else { return }
            shouldShowCoachingOverlay = !(surfaceDetected && isTrackingNormal)
        }
    }
    var isTrackingNormal: Bool = false {
        didSet {
            guard oldValue != isTrackingNormal else { return }
            shouldShowCoachingOverlay = !(surfaceDetected && isTrackingNormal)
        }
    }
    
    @Published var shouldShowCoachingOverlay: Bool = false {
        didSet {
            guard oldValue != shouldShowCoachingOverlay else { return }
            uiCoachingView?.setActive(shouldShowCoachingOverlay, animated: true)
        }
    }
    
    /// Keeps track of currently active
    var activeStage: Stage?
    
    // MARK: - Initializatin
    override init() {
        sceneLoader = SceneLoader()
        
        super.init()
        
        let stream = sceneLoader.$bundleVirtualSets.sink { sets in
            self.state = .pickingSet
        }
        stream.store(in: &streams)
    }
    
    // MARK: - Methods
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
            //configuration.sceneReconstruction = .mesh
            //arView?.environment.sceneUnderstanding.options.insert([.occlusion])
            session.run(configuration, options: options)
        }
        
        let resolution = configuration.videoFormat.imageResolution
        os_log(.info, "captured video resolution:\n%s", "\(resolution)")
    }
    
    // MARK: - User Interaction
    func userDidPickSet(_ set: BundleVirtualSet) {
        state = .exploringScene
        sceneLoader.loadBundleSet(set) { entity, error in
            guard error == nil, let entity = entity else { return }
            
            self.arView?.scene.addAnchor(entity)
            self.activeStage = entity
        }
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

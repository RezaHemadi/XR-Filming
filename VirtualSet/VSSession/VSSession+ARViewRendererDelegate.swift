//
//  VSSession+ARViewRendererDelegate.swift
//  VirtualSet
//
//  Created by Reza on 11/12/21.
//  Copyright © 2021 Dynamic Stacks LTD. All rights reserved.
//

import Foundation
import Metal
import os.signpost

extension VSSession: ARViewRendererDelegate {
    func recorder(_ recorder: Recorder, didFinishWritingVideo: Bool) {
        announce("Video was saved to Photos gallery")
        
        // Send video saved command to watch
        watchSession?.sendVideoSavedCommand()
    }
    
    func renderer(_ renderer: ARViewRenderer, didSaveSnapshot: Bool) {
        announce("Snapshot was saved to Photos gallery")
    }
    
    func rendererDidUpdate(_ renderer: ARViewRenderer, watchTexture: MTLTexture, elapsed: TimeInterval?) {
        self.watchSession?.update(texture: watchTexture, elapsed: elapsed)
    }
    
    func rendererDidEncounterNetwordError(_ renderer: ARViewRenderer) {
        showNetworkError()
    }
    
    func rendererDidUpdateWatchTexture(_ renderer: ARViewRenderer, width: Int, height: Int) {
        // Send Dimension command to watch
        watchSession?.sendDimensionUpdate(width: width, height: height)
    }
    
    func rendererTrackingStateDidChange(_ renderer: ARViewRenderer, isTracking: Bool) {
        guard state == .exploringScene(.viewing) || state == .exploringScene(.recording) else { return }
        
        coachingOverlay?.setActive(!isTracking, animated: true)
    }
}

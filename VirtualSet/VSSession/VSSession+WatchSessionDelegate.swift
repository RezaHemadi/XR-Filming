//
//  VSSession+WatchSessionDelegate.swift
//  VirtualSet
//
//  Created by Reza on 11/12/21.
//  Copyright © 2021 Dynamic Stacks LTD. All rights reserved.
//

import Foundation

extension VSSession: WatchSessionDelegate {
    func watchSessionDidReceiveRecordCommand(_ watchSession: WatchSession) {
        // Make sure session is prepared to start recording
        guard case let .exploringScene(exploringState) = state else { return }
        
        // Make sure session is not recording
        guard exploringState != .recording else { return }
        
        DispatchQueue.main.async {
            self.isRecording = true
        }
    }
    
    func watchSessionDidReceiveStopCommand(_ watchSession: WatchSession) {
        // Make sure session is recording
        guard case let .exploringScene(exploringState) = state else { return }
        guard exploringState == .recording else { return }
        
        DispatchQueue.main.async {
            self.isRecording = false
        }
    }
    
    func watchSessionReachabilityChanged(_ watchSession: WatchSession) {
        arViewRenderer?.shouldSendWatchUpdates = watchSession.session.isReachable
    }
}

//
//  VSSession+ARCoachingOverlayDelegate.swift
//  VirtualSet
//
//  Created by Reza on 12/22/21.
//  Copyright © 2021 Dynamic Stacks LTD. All rights reserved.
//

import Foundation
import ARKit
import os.signpost

extension VSSession: ARCoachingOverlayViewDelegate {
    func coachingOverlayViewDidRequestSessionReset(_ coachingOverlayView: ARCoachingOverlayView) {
        resetTracking()
    }
    
    func coachingOverlayViewWillActivate(_ coachingOverlayView: ARCoachingOverlayView) {
        allowCoachingViewHitTesting = true
        os_log(.info, "coaching overlay will activate")
    }
    
    func coachingOverlayViewDidDeactivate(_ coachingOverlayView: ARCoachingOverlayView) {
        allowCoachingViewHitTesting = false
        os_log(.info, "coaching overlay will deactivate")
    }
}

//
//  ARPlaneAnchor+Utilities.swift
//  VirtualSet
//
//  Created by Reza on 9/22/21.
//

import Foundation
import ARKit

extension ARPlaneAnchor {
    var area: Float {
        switch alignment {
        case .horizontal:
            return (extent.x * extent.z)
        case .vertical:
            return (extent.y * extent.x)
        }
    }
}

//
//  VirtualSet.swift
//  VirtualSet
//
//  Created by Reza on 9/5/21.
//

import Foundation
import SwiftUI
import RealityKit

struct VirtualSet: Identifiable {
    var image: Image
    
    var set: Entity & HasAnchoring
    
    var id: Int
}

//
//  PFVirtualStage.swift
//  VirtualSet
//
//  Created by Reza on 11/6/21.
//  Copyright © 2021 Dynamic Stacks LTD. All rights reserved.
//

import Foundation
import Parse

class PFVirtualStage: PFObject, PFSubclassing {
    @NSManaged var Name: String
    @NSManaged var Attribution: String
    @NSManaged var Order: NSNumber
    @NSManaged var Thumbnail: PFFileObject
    @NSManaged var IsFree: Bool
    @NSManaged var Model: PFFileObject
    @NSManaged var EnvironmentMap: PFFileObject?
    @NSManaged var Keywords: [String]
}
extension PFVirtualStage {
    static func parseClassName() -> String {
        return "VirtualStage"
    }
}

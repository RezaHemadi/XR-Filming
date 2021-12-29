//
//  PFVideoRecordings.swift
//  VirtualSet
//
//  Created by Reza on 11/9/21.
//  Copyright © 2021 Dynamic Stacks LTD. All rights reserved.
//

import Foundation
import Parse

class PFVideoRecordings: PFObject {
    @NSManaged var Duration: NSNumber
    @NSManaged var IsLandscape: Bool
    @NSManaged var Stage: PFVirtualStage
    @NSManaged var StageName: String
    @NSManaged var UsedCustomPic: Bool
}

extension PFVideoRecordings: PFSubclassing {
    static func parseClassName() -> String {
        return "VideoRecordings"
    }
}

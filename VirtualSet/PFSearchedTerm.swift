//
//  PFSearchedTerm.swift
//  VirtualSet
//
//  Created by Reza on 11/9/21.
//  Copyright © 2021 Dynamic Stacks LTD. All rights reserved.
//

import Foundation
import Parse

class PFSearchedTerm: PFObject {
    @NSManaged var IsLandscape: Bool
    @NSManaged var SearchedString: String
}
extension PFSearchedTerm: PFSubclassing {
    class func parseClassName() -> String {
        return "SearchedTerms"
    }
}

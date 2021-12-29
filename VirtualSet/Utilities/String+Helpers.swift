//
//  String+Helpers.swift
//  VirtualSet
//
//  Created by Reza on 11/13/21.
//  Copyright © 2021 Dynamic Stacks LTD. All rights reserved.
//

import Foundation

extension String {
    var whiteSpacesRemoved: String {
        components(separatedBy: .whitespaces).joined()
    }
}

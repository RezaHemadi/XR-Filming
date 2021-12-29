//
//  MTLTexture+Helpers.swift
//  VirtualSet
//
//  Created by Reza on 12/21/21.
//  Copyright © 2021 Dynamic Stacks LTD. All rights reserved.
//

import Foundation
import Metal

extension MTLTexture {
    var dimension: TextureDimension {
        get {
            return .init(width: width, height: height)
        }
    }
}

struct TextureDimension {
    let width: Int
    let height: Int
    
    static func ==(lhs: TextureDimension, rhs: TextureDimension) -> Bool {
        return (lhs.width == rhs.width && lhs.height == rhs.height)
    }
}

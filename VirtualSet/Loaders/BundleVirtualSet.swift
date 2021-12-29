//
//  BundleVirtualSet.swift
//  VirtualSet
//
//  Created by Reza on 9/6/21.
//

import Foundation

struct BundleVirtualSet: Codable, Identifiable, Hashable, Equatable {
    var id: Int
    var name: String
    var description: String
    var environmentMap: String?
    var keywords: [String]
}

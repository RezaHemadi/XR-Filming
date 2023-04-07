//
//  SetPreview.swift
//  VirtualSet
//
//  Created by Reza on 11/6/21.
//  Copyright © 2021 Dynamic Stacks LTD. All rights reserved.
//

import Foundation
import SwiftUI
import os.signpost

struct SetPreview: Identifiable, Equatable {
    static func == (lhs: SetPreview, rhs: SetPreview) -> Bool {
        lhs.id == rhs.id
    }
    
    enum Source {
        case bundle(BundleVirtualSet)
        case server(VirtualStage)
    }
    
    // MARK: - Properties
    var id: Int
    var name: String
    var description: String
    var source: SetPreview.Source
    var downloaded: Bool
    
    // MARK: - Initialization
    init(id: Int, name: String, description: String, source: Source) {
        self.id = id
        self.name = name
        self.description = description
        self.source = source
        downloaded = false
    }
    
    init(set: BundleVirtualSet) {
        id = set.id
        name = set.name
        description = set.description
        source = .bundle(set)
        downloaded = true
    }
    
    init(set: VirtualStage) {
        name = set.name
        id = set.order
        description = set.attribution
        source = .server(set)
        downloaded = false
    }
    
    // MARK: - Methods
    /// searches the set name and keywords for a given search term
    func contains(_ term: String) -> Bool {
        if name.contains(term) {
            return true
        }
        
        switch source {
        case .server(let stage):
            if stage.object.Keywords.contains(where: {$0.contains(term)}) {
                return true
            }
        case .bundle(let set):
            if set.keywords.contains(where: {$0.contains(term)}) {
                return true
            }
        }
        
        return false
    }
}

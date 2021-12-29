//
//  StageInfo.swift
//  VirtualSet
//
//  Created by Reza on 11/13/21.
//  Copyright © 2021 Dynamic Stacks LTD. All rights reserved.
//

import Foundation
import os.signpost

struct StageInfo: Codable {
    let name: String
    let updatedAt: Date
    let objectID: String
    
    var modelURL: URL {
        let modelsURL = SceneLoader.modelsDir
        return modelsURL.appendingPathComponent(name.whiteSpacesRemoved).appendingPathComponent(name.whiteSpacesRemoved).appendingPathExtension("reality")
    }
    
    var skyboxURL: URL? {
        let modelsURL = SceneLoader.modelsDir
        let fileManager = FileManager.default
        let contents = try! fileManager.contentsOfDirectory(at: modelsURL.appendingPathComponent(name.whiteSpacesRemoved), includingPropertiesForKeys: nil, options: [])
        return contents.first { url in
            return url.lastPathComponent.contains("skybox")
        }
    }
}

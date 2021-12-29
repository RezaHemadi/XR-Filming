//
//  VideoFeedScene.swift
//  XRFilming WatchKit Extension
//
//  Created by Reza on 11/14/21.
//  Copyright © 2021 Dynamic Stacks LTD. All rights reserved.
//

import Foundation
import SpriteKit
import os.signpost

class VideoFeedScene: SKScene {
    var width: Int?
    var height: Int?
    
    func updateTexture(_ data: Data?) {
        guard data != nil, width != nil, height != nil else { return }
        
        DispatchQueue.main.async {
            self.removeAllChildren()
            
            let texture = SKTexture(data: data!, size: .init(width: self.width!, height: self.height!), rowLength: UInt32(4 * self.width!), alignment: 4)
            let node = SKSpriteNode(texture: texture, size: .init(width: 200, height: 200))
            node.position = .init(x: 100.0, y: 100.0)
            node.zRotation = .pi
            self.addChild(node)
        }
    }
}

//
//  MTKViewContainer.swift
//  VirtualSet
//
//  Created by Reza on 9/21/21.
//

import Foundation
import SwiftUI
import UIKit
import MetalKit
import os.signpost

struct MTKViewContainer: UIViewRepresentable {
    
    unowned var session: VSSession
    
    class Coordinator: NSObject {
        var parent: MTKViewContainer
        var renderer: Renderer?
        
        init(_ mtkViewContainer: MTKViewContainer) {
            parent = mtkViewContainer
        }
    }
    
    func makeUIView(context: Context) -> MTKView {
        let view = MTKView()
        view.device = MTLCreateSystemDefaultDevice()
        view.backgroundColor = UIColor.clear
        view.delegate = context.coordinator
        view.framebufferOnly = false
        
        #if !targetEnvironment(simulator)
        let renderer = Renderer(renderDestination: view, device: view.device!)
        context.coordinator.renderer = renderer
        #endif
        
        return view
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {
        
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }
}
extension MTKViewContainer.Coordinator: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        renderer?.drawRectResized(size: size)
    }
    
    func draw(in view: MTKView) {
        renderer?.update()
    }
}

extension MTKView: RenderDestinationProvider {}

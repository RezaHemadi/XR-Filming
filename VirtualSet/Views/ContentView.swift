//
//  ContentView.swift
//  VirtualSet
//
//  Created by Reza on 9/3/21.
//

import SwiftUI
import RealityKit

struct ContentView : View {
    // MARK: - Properties
    @EnvironmentObject var session: VSSession
    
    var dimBackground: Bool {
        switch session.state {
        case .initializing, .pickingSet:
            return true
        case .inProgress:
            return false
        }
    }
    
    var body: some View {
        ZStack{
            ARViewContainer()
                .edgesIgnoringSafeArea(.all)
            
            if dimBackground {
                Color.gray.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
            }
            
            switch session.state {
            case .initializing, .pickingSet:
                ScenePickerView(session: session)
            default:
                EmptyView()
            }
        }
    }
}

struct ARViewContainer: UIViewRepresentable {
    
    func makeUIView(context: Context) -> ARView {
        
        let arView = ARView(frame: .zero)
        
        // Load the "Box" scene from the "Experience" Reality File
        let boxAnchor = try! Experience.loadBox()
        
        // Add the box anchor to the scene
        arView.scene.anchors.append(boxAnchor)
        
        return arView
        
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {}
    
}

#if DEBUG
struct ContentView_Previews : PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(VSSession())
            .previewDevice(PreviewDevice(rawValue: "iPhone 12 Pro Max"))
            .previewDisplayName("iPhone 12 Pro Max")
    }
}
#endif

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
        case .exploringScene:
            return false
        }
    }
    
    var body: some View {
        ZStack{
            ARViewContainer(session: session)
                .edgesIgnoringSafeArea(.all)
            
            if dimBackground {
                Color.gray.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
            }
            
            switch session.state {
            case .initializing:
                Text("Initializing...")
            case .pickingSet:
                ScenePickerView()
                    .environmentObject(session)
            case .exploringScene:
                VSControlsView()
            }
        }
    }
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

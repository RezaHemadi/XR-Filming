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
    static let backgroundGray: Color = Color(white: 70.0/255.0)
    
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
                .opacity(dimBackground ? 0.17 : 1.0)
                .edgesIgnoringSafeArea(.all)
            /*
            if dimBackground {
                Color.gray.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
            }*/
            
            MainView()
                .environmentObject(session)
            
            if session.shouldShowCoachingOverlay, let coachingView = session.coachingOverlay {
                coachingView
            }
        }
        .background(Self.backgroundGray)
        .edgesIgnoringSafeArea(.all)
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

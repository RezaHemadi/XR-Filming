//
//  MainView.swift
//  VirtualSet
//
//  Created by Reza on 9/11/21.
//

import SwiftUI

struct MainView: View {
    @EnvironmentObject var session: VSSession
    var height: CGFloat {
        UIScreen.main.bounds.height
    }
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    var body: some View {
        Group {
            switch session.state {
            case .initializing:
                Text("Initializing...")
            case .loadingModel, .exploringScene:
                Group {
                    VSControlsView()
                        .environmentObject(session)
                        .disabled(session.state == .loadingModel)
                    
                    if session.state == .loadingModel {
                        ZStack {
                            LoadingView()
                                .frame(height: 350, alignment: Alignment(horizontal: .center, vertical: .bottom))
                            
                            if session.tip != nil {
                                TipView(tip: session.tip!)
                                    .offset(y: verticalSizeClass == .regular ? -height / 4 : 0)
                                    .animation(.default)
                                    .transition(.opacity)
                            }
                        }
                    }
                }
            case .pickingSet:
                ScenePickerView()
                    .environmentObject(session)
            }
            
            VStack {
                Spacer()
                NetworkErrorView()
                    .frame(width: 0.9 * UIScreen.main.bounds.width, height: 50.0, alignment: .center)
                    .opacity(session.shouldShowNetworkError ? 1.0 : 0.0)
                    .animation(.default, value: session.shouldShowNetworkError)
            }
            /*
            if session.shouldShowNetworkError {
                
            } */
        }
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
            .environmentObject(VSSession())
    }
}

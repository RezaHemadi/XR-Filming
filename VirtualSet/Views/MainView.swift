//
//  MainView.swift
//  VirtualSet
//
//  Created by Reza on 9/11/21.
//

import SwiftUI

struct MainView: View {
    @EnvironmentObject var session: VSSession
    
    var body: some View {
        switch session.state {
        case .initializing:
            Text("Initializing...")
        case .pickingSet:
            ScenePickerView(session: session)
        case .exploringScene:
            VSControlsView()
                .padding([.top, .bottom], 30.0)
                .padding([.leading, .trailing], 10.0)
        }
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
            .environmentObject(VSSession())
    }
}

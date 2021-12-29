//
//  VirtualSetApp.swift
//  XRFilming WatchKit Extension
//
//  Created by Reza on 11/8/21.
//  Copyright © 2021 Dynamic Stacks LTD. All rights reserved.
//

import SwiftUI

@main
struct VirtualSetApp: App {
    
    var phoneConnectivity = PhoneConnectivity()
    
    @SceneBuilder var body: some Scene {
        WindowGroup {
            NavigationView {
                ContentView()
                    .environmentObject(phoneConnectivity)
            }
        }

        WKNotificationScene(controller: NotificationController.self, category: "myCategory")
    }
}

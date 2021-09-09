//
//  VSControlsView.swift
//  VirtualSet
//
//  Created by Reza on 9/3/21.
//

import SwiftUI

struct VSControlsView: View {
    // MARK: - Properties
    @State var orientation = UIDevice.current.orientation
    @EnvironmentObject var session: VSSession
    
    // MARK: - View
    var body: some View {
        if orientation.isLandscape {
            // Landscape Orientation
            HStack{
                
                // Vertical Stack Containing Left Screen
                VStack{
                    ChangeSceneView()
                    
                    Spacer()
                    
                    MoreOptionsView()
                }
                .padding(.all, 15)
                
                // Push left and right buttons away
                Spacer()
                
                VStack(spacing: 50){
                    AddItemView()
                    
                    RecordView(isRecording: $session.isRecording, isLandspace: orientation.isLandscape)
                    
                    SnapshotView()
                }
            }
            .onRotate { newOrientation in
                orientation = newOrientation
            }
        } else {
            // Portrait Orientation
            // Vertical Stack to hold top and bottom screen controls
            VStack{
                // Horizontal Stack containing Top Screen Controls
                HStack(alignment: .top){
                    ChangeSceneView()
                        .onTapGesture {
                            session.state = .pickingSet
                        }
                    
                    Spacer()
                    
                    MoreOptionsView()
                        .padding(.top, 15)
                }
                .padding(.all, 15)
                
                Spacer()
                
                // Horizontal Stack Containing Bottom Screen Controls
                HStack(spacing: 50){
                    AddItemView()
                    
                    RecordView(isRecording: $session.isRecording, isLandspace: orientation.isLandscape)
                
                    SnapshotView()
                }
            }
            .onRotate { newOrientation in
                orientation = newOrientation
            }
        }
    }
}

struct VSControlsView_Previews: PreviewProvider {
    static var previews: some View {
        let deivces = ["iPhone 12 Pro Max", "iPad Pro (12.9-inch) (5th generation)"]
        ForEach(deivces, id: \.self) { deviceName in
            VSControlsView()
                .previewDevice(PreviewDevice(rawValue: deviceName))
                .previewDisplayName(deviceName)
        }
    }
}

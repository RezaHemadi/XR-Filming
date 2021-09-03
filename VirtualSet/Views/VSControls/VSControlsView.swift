//
//  VSControlsView.swift
//  VirtualSet
//
//  Created by Reza on 9/3/21.
//

import SwiftUI

struct VSControlsView: View {
    var body: some View {
        // Vertical Stack to hold top and bottom screen controls
        VStack{
            // Horizontal Stack containing Top Screen Controls
            HStack(alignment: .top){
                ChangeSceneView()
                
                Spacer()
                
                MoreOptionsView()
                    .padding(.top, 15)
            }
            .padding(.all, 15)
            
            Spacer()
            
            // Horizontal Stack Containing Bottom Screen Controls
            HStack(spacing: 70){
                AddItemView()
                
                RecordView(isRecording: false)
                
                SnapshotView()
            }
        }
    }
}

struct VSControlsView_Previews: PreviewProvider {
    static var previews: some View {
        VSControlsView()
    }
}

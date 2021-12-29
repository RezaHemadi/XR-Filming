//
//  ChangeSceneView.swift
//  VirtualSet
//
//  Created by Reza on 9/3/21.
//

import SwiftUI

struct ChangeSceneView: View {
    var body: some View {
        LinearGradient(colors: [ButtonGradientColors[1],
                                ButtonGradientColors[0]],
                       startPoint: .bottomLeading,
                       endPoint: .topTrailing)
            .mask(Image("ChangeScene")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 40, height: 40)
            )
            .frame(width: 45, height: 45)
        
    }
}

struct ChangeSceneView_Previews: PreviewProvider {
    static var previews: some View {
        ChangeSceneView()
    }
}

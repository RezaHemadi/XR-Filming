//
//  SnapshotView.swift
//  VirtualSet
//
//  Created by Reza on 9/3/21.
//

import SwiftUI

struct SnapshotView: View {
    var body: some View {
        LinearGradient(colors: [ButtonGradientColors[1], ButtonGradientColors[0]],
                       startPoint: .bottom,
                       endPoint: .top)
            .mask(Image(systemName: "camera.fill")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 40, height: 40)
            )
            .frame(width: 50, height: 50)
            
    }
}

struct SnapshotView_Previews: PreviewProvider {
    static var previews: some View {
        SnapshotView()
    }
}

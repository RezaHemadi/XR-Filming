//
//  SnapshotView.swift
//  VirtualSet
//
//  Created by Reza on 9/3/21.
//

import SwiftUI

struct SnapshotView: View {
    var body: some View {
        Image(systemName: "camera.fill")
            .resizable()
            .foregroundColor(.gray)
            .frame(width: 64, height: 45)
    }
}

struct SnapshotView_Previews: PreviewProvider {
    static var previews: some View {
        SnapshotView()
    }
}

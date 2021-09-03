//
//  MoreOptionsView.swift
//  VirtualSet
//
//  Created by Reza on 9/3/21.
//

import SwiftUI

struct MoreOptionsView: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.gray)
                .frame(width: 60, height: 30)
            
            Rectangle()
                .fill(Color.white)
                .frame(width: 5, height: 5)
                .offset(x: -10)
            
            Rectangle()
                .fill(Color.white)
                .frame(width: 5, height: 5)
            
            Rectangle()
                .fill(Color.white)
                .frame(width: 5, height: 5)
                .offset(x: 10)
        }
    }
}

struct MoreOptionsView_Previews: PreviewProvider {
    static var previews: some View {
        MoreOptionsView()
    }
}

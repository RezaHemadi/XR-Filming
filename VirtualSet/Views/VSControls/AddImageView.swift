//
//  AddImageView.swift
//  VirtualSet
//
//  Created by Reza on 10/5/21.
//

import SwiftUI

struct AddImageView: View {
    var body: some View {
        Image("AddImageIcon")
            .resizable()
            .scaledToFill()
            .frame(width: 40, height: 40)
            .offset(x: 5.0, y: 2.0)
    }
}

struct AddImageView_Previews: PreviewProvider {
    static var previews: some View {
        AddImageView()
    }
}

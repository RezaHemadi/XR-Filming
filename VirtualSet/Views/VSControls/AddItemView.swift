//
//  AddItemView.swift
//  VirtualSet
//
//  Created by Reza on 9/3/21.
//

import SwiftUI

struct AddItemView: View {
    var body: some View {
        Image(systemName: "plus.circle.fill")
            .resizable()
            .foregroundColor(.gray)
            .frame(width: 53, height: 53)
    }
}

struct AddItemView_Previews: PreviewProvider {
    static var previews: some View {
        AddItemView()
    }
}

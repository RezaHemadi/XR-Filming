//
//  SearchBarView.swift
//  VirtualSet
//
//  Created by Reza on 9/11/21.
//

import SwiftUI

struct SearchBarView: View {
    // MARK: - Properties
    @Binding var text: String
    
    @State private var isEditing: Bool = false
    
    // MARK: - Contents
    var body: some View {
        HStack {
            TextField("Search", text: $text)
                .foregroundColor(.gray)
                .padding(7)
                .frame(width: 200)
                .onTapGesture {
                    isEditing = true
                }
            
            Image(systemName: "magnifyingglass.circle")
                .resizable()
                .foregroundColor(.gray)
                .frame(width: 15, height: 15)
                .padding(10)
            
            if isEditing {
                Button(action: {
                    isEditing = false
                    text = ""
                    hideKeyboard()
                }) {
                    Image(systemName: "xmark.circle")
                }
                .foregroundColor(.gray)
                .padding(10)
                .transition(.opacity)
                .animation(.default)
            }
        }
        .background(Color(.black).opacity(0.47))
        .cornerRadius(8.0)
        .padding(.horizontal, 10.0)
    }
}

struct SearchBarView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Image("Dome")
                .resizable()
                .scaledToFill()
                .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height, alignment: .center)
            SearchBarView(text: .constant(""))
        }
    }
}

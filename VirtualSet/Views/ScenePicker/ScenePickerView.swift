//
//  ScenePickerView.swift
//  VirtualSet
//
//  Created by Reza on 9/3/21.
//

import SwiftUI

struct ScenePickerView: View {
    
    var session: VSSession
    @State var searchTerm: String = ""
    static let backgroundGray: Color = Color(white: 50.0/255.0)
    
    var body: some View {
        VStack(alignment: .center) {
            Text("Scan the area and \ntap to select scene")
                .font(.system(size: 24))
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 300)
            
            VStack {
                SearchBarView(text: $searchTerm)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top){
                        ForEach(session.sceneLoader.bundleVirtualSets.filter {searchTerm.isEmpty ? true : $0.name.contains(searchTerm)}) { set in
                            Image(set.name)
                                .resizable()
                                .cornerRadius(10)
                                .frame(width: 120, height: 120)
                                .scaledToFit()
                                .padding(10)
                                .onTapGesture {
                                    session.userDidPickSet(set)
                                }
                        }
                    }
                }
            }
            .frame(height: 200)
            .background(Self.backgroundGray.opacity(0.6))
        }
    }
}

struct ScenePickerView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Image("Dome")
                .resizable()
                .scaledToFill()
            
            ScenePickerView(session: VSSession(),
                            searchTerm: "")
        }
    }
}

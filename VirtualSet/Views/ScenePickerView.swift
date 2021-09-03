//
//  ScenePickerView.swift
//  VirtualSet
//
//  Created by Reza on 9/3/21.
//

import SwiftUI

struct ScenePickerView: View {
    
    var session: VSSession
    
    var body: some View {
        VStack(alignment: .center) {
            Text("Scan the area and \ntap to select scene")
                .font(.system(size: 24))
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 300)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top){
                    Image("charleyrivers")
                        .resizable()
                        .cornerRadius(10)
                        .frame(width: 120, height: 120)
                        .padding(10)
                        .onTapGesture {
                            session.state = .inProgress
                        }
                }
            }
            .frame(height: 200)
            .background(Color.gray.opacity(0.6))
        }
    }
}

struct ScenePickerView_Previews: PreviewProvider {
    static var previews: some View {
        ScenePickerView(session: VSSession())
    }
}

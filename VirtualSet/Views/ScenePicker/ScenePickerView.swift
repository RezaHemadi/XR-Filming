//
//  ScenePickerView.swift
//  VirtualSet
//
//  Created by Reza on 9/3/21.
//

import SwiftUI
import os.signpost

struct ScenePickerView: View {
    
    @EnvironmentObject var session: VSSession
    @State private var searchTerm: String = ""
    @State private var detailedSets = [SetPreview]()
    
    static let backgroundGray: Color = Color(white: 50.0/255.0)
    
    var body: some View {
        ZStack(alignment: Alignment(horizontal: .leading, vertical: .top)) {
            VStack(alignment: .center) {
                Text("Scan the Area and \nTap to Select Scene")
                    .font(.custom("SF-Pro", size: 20.0))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .frame(width: 300)
                    .padding([.top])
                        
                VStack {
                    SearchBarView(text: $searchTerm)
                        .padding(.top, 10)
                        .onChange(of: searchTerm) { newValue in
                            session.searchTermChanged(newValue: newValue)
                        }
                        
                    ScrollView(.horizontal, showsIndicators: true) {
                        LazyHStack(alignment: .top){
                            ForEach(session.setPreviews.filter { searchTerm.isEmpty ? true : $0.contains(searchTerm)}) { set in
                                SetCellView(set: set, session: session, detailedSets: $detailedSets)
                            }
                        }
                    }
                }
                .frame(height: 230)
                .background(Self.backgroundGray.opacity(0.6))
            }
            .padding(.top, 15)
            VStack(alignment: .leading) {
                ForEach(detailedSets) { set in
                    SetDetailView(set: set)
                        .padding()
                        .offset(y: 150)
                        .frame(height: 400)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now().advanced(by: .seconds(1))) {
                                if let index = detailedSets.firstIndex(of: set) {
                                    let _ = withAnimation {
                                        detailedSets.remove(at: index)
                                    }
                                }
                            }
                        }
                }
            }
            .frame(height: 400)
        }
    }
}

struct ScenePickerView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Image("Dome")
                .resizable()
                .scaledToFill()
            
            ScenePickerView()
                .environmentObject(VSSession())
        }
        .previewInterfaceOrientation(.landscapeRight)
    }
}

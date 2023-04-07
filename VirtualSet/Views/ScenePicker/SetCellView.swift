//
//  SetCellView.swift
//  VirtualSet
//
//  Created by Reza on 9/11/21.
//

import SwiftUI
import os.signpost

struct SetCellView: View {
    var set: SetPreview
    var session: VSSession
    @Binding var detailedSets: [SetPreview]
    @State private var infoTappedTime: DispatchTime?
    
    var bundlePreview: some View {
        Button(action: {session.userDidPickSet(set)}) {
            Image(set.name)
                .resizable()
                .cornerRadius(10)
                .frame(width: 120, height: 120)
                .scaledToFit()
                .padding(10)
        }
    }
    
    var body: some View {
        // View
        VStack {
            ZStack(alignment: Alignment(horizontal: .trailing, vertical: .top)) {
                switch set.source {
                case .bundle:
                    bundlePreview
                case .server(let virtualStage):
                    ServerStageCellView(session: session, set: set)
                        .environmentObject(virtualStage)
                }
                
                
                Button(action: {
                    guard !detailedSets.contains(where: {$0.id == set.id}) else { return }
                    
                    if infoTappedTime == nil {
                        infoTappedTime = DispatchTime.now()
                    } else {
                        let elapsed = infoTappedTime!.distance(to: DispatchTime.now()) // in nanoseconds
                        
                        if case let .nanoseconds(elapsedNanoSeconds) = elapsed {
                            if elapsedNanoSeconds < 5 * 1_000_000_000 {
                                return
                            } else {
                                infoTappedTime = DispatchTime.now()
                            }
                        }
                    }
                    
                    detailedSets.append(set)
                })
                {
                    Image(systemName: "info.circle")
                        .resizable()
                        .frame(width: 20, height: 20, alignment: .bottomLeading)
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                }
            }
            
            Text(set.name)
                .font(.custom("SF-Pro", size: 12.0))
                .frame(width: 120.0)
                .foregroundColor(.white)
                .padding(.top, -13)
        }
    }
}

struct SetCellView_Previews: PreviewProvider {
    static var previews: some View {
        SetCellView(set: VSSession().setPreviews[1], session: VSSession(),
                    detailedSets: .constant([]))
    }
}

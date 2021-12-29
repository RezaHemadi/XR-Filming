//
//  ServerStageCellView.swift
//  VirtualSet
//
//  Created by Reza on 12/5/21.
//  Copyright © 2021 Dynamic Stacks LTD. All rights reserved.
//

import SwiftUI

struct ServerStageCellView: View {
    @EnvironmentObject var virtualStage: VirtualStage
    var session: VSSession
    var set: SetPreview
    @State private var thumb: Image?
    
    var downloadIcon: some View {
        Image(systemName: "square.and.arrow.down")
            .resizable()
            .frame(width: 40.0, height: 40.0, alignment: .center)
            .foregroundColor(.white)
            .scaledToFit()
            .padding(10)
    }
    
    var body: some View {
        // Actions
        let downloadAction: (VirtualStage) -> Void = { virtualStage in
            virtualStage.download()
        }
        ZStack {
            Button(action: {if (virtualStage.downloadDone) { session.userDidPickSet(set) } }) {
                if thumb != nil {
                    thumb!
                        .resizable()
                        .cornerRadius(10)
                        .frame(width: 120, height: 120)
                        .scaledToFit()
                        .padding(10)
                        .opacity(virtualStage.downloadInProgress ? 0.5 : 1.0)
                } else {
                    ProgressView()
                        .frame(width: 120.0, height: 120.0)
                }
            }
            .onAppear {
                loadImage(stage: virtualStage)
            }
            
            if !virtualStage.downloadInProgress {
                if !virtualStage.downloadDone {
                    Button(action: {downloadAction(virtualStage)}) {
                        downloadIcon
                            .frame(width: 130.0, height: 130.0)
                            .opacity(virtualStage.downloadDone ? 0.0 : 100)
                    }
                }
                
            } else {
                ProgressView(value: virtualStage.progress / 100.0)
                    .accentColor(ButtonGradientColors[1])
                    .frame(width: 110.0, height: 130.0)
            }
        }
    }
    func loadImage(stage: VirtualStage) {
        stage.object.Thumbnail.getDataInBackground { data, error in
            if let data = data {
                if let uiImage = UIImage(data: data) {
                    self.thumb = Image(uiImage: uiImage)
                }
            }
        }
    }
}

struct ServerStageCellView_Previews: PreviewProvider {
    static var previews: some View {
        ServerStageCellView(session: VSSession(), set: VSSession().setPreviews[0])
    }
}

//
//  AnnouncementView.swift
//  VirtualSet
//
//  Created by Reza on 10/6/21.
//

import SwiftUI

struct AnnouncementView: View {
    var text: String
    @State private var yOffset: CGFloat = -120
    @State private var opacity: CGFloat = 1.0
    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    init(_ text: String) {
        self.text = text
    }
    
    var body: some View {
        VStack {
            ZStack(alignment: .top) {
                Color.init(red: 0.0, green: 202/255, blue: 94/255)
                                .opacity(0.71)
                                .frame(height: 70)
                
                Text(text)
                    .font(.system(size: 24, weight: .regular, design: .default))
                    .foregroundColor(.white)
                    .frame(height: 70, alignment: .center)
                    .offset(y: horizontalSizeClass == .compact ? 15.0 : 0.0)
            }
            .edgesIgnoringSafeArea(.all)
            
            Spacer()
        }
        .offset(y: yOffset)
        .opacity(opacity)
        .onAppear {
            let animation = Animation.easeOut(duration: 0.7)
            
            withAnimation(animation) {
                yOffset = 0
            }
            
            let removeAnim = Animation.easeIn(duration: 0.7).delay(kAnnouncementTime + 0.7)
            withAnimation(removeAnim) {
                opacity = 0.0
            }
        }
    }
}

struct AnnouncementView_Previews: PreviewProvider {
    static var previews: some View {
        AnnouncementView("Video was saved to gallery")
    }
}

//
//  TipView.swift
//  VirtualSet
//
//  Created by Reza on 10/10/21.
//

import SwiftUI

struct TipView: View {
    @State private var opacity: CGFloat = 0.0
    var tip: String
    var screenWidth: CGFloat {
        UIScreen.main.bounds.width
    }
    
    var body: some View {
        Text(tip)
            .fontWeight(.bold)
            .font(.title)
            .multilineTextAlignment(.center)
            .foregroundColor(ButtonGradientColors[0])
            .padding()
            .frame(width: min(screenWidth * 0.9, 400), alignment: .center)
            .overlay {
                RoundedRectangle(cornerRadius: 15.0)
                    .stroke(ButtonGradientColors[0], lineWidth: 5.0)
            }
            .opacity(opacity)
            .onAppear {
                let anim = Animation.easeOut(duration: 1.0)
                
                withAnimation(anim) {
                    opacity = 1.0
                }
            }
            .onDisappear {
                let anim = Animation.easeIn(duration: 1.0)
                
                withAnimation(anim) {
                    opacity = 0.0
                }
            }
    }
}

struct TipView_Previews: PreviewProvider {
    static var previews: some View {
        TipView(tip: "Tip: You can remove photographs by long tap")
    }
}

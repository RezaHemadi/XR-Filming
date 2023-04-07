//
//  LoadingView.swift
//  VirtualSet
//
//  Created by Reza on 10/5/21.
//

import SwiftUI

struct LoadingView: View {
    @State private var scale: CGFloat = 1.0
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "circle.hexagongrid")
                .resizable()
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .scaleEffect(scale)
                .onAppear {
                    let baseAnimation = Animation.easeInOut(duration: 1.0)
                    let repeated = baseAnimation.repeatForever(autoreverses: true)
                    withAnimation(repeated) {
                        scale = 1.3
                    }
                }
            Text("Scene is loading")
                .font(.custom("SF-Pro", size: 20.0))
                .foregroundColor(.white)
        }
    }
}

struct LoadingView_Previews: PreviewProvider {
    static var previews: some View {
        let deivces = ["iPhone 12 Pro Max", "iPad Pro (12.9-inch) (5th generation)"]
        ForEach(deivces, id: \.self) { deviceName in
            ZStack {
                Image("Dome")
                    .resizable()
                    .scaledToFill()
                    .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height, alignment: .center)
                
                LoadingView()
            }
            .previewDevice(PreviewDevice(rawValue: deviceName))
            .previewDisplayName(deviceName)
        }
    }
}

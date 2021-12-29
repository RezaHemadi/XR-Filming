//
//  RollingFilmsView.swift
//  VirtualSet
//
//  Created by Reza on 10/9/21.
//

import SwiftUI

struct RollingFilmsView: View {
    @State var rotationAngle: Angle = .init(degrees: 0)
    @State var rotationDuration: Double = 0.7
    
    var animation: Animation {
        Animation.linear(duration: rotationDuration).repeatCount(3, autoreverses: false)
    }
    
    var body: some View {
        ZStack {
            ZStack {
                Image("Film")
                    .resizable()
                    .frame(width: 140, height: 140)
                    .rotationEffect(rotationAngle)
                    .onAppear {
                        withAnimation(animation) {
                            rotationAngle = .init(degrees: 360.0)
                        }
                        let secondAnimation = Animation.linear(duration: 0.4).repeatForever(autoreverses: false).delay(2.1)
                        withAnimation(secondAnimation) {
                            rotationAngle = .init(degrees: 720.0)
                        }
                }
            }
            
            ZStack {
                Image("Film")
                    .resizable()
                    .frame(width: 85, height: 85)
                    .rotationEffect(rotationAngle)
                    .onAppear {
                        withAnimation(animation) {
                            rotationAngle = .init(degrees: 360.0)
                        }
                }
            }
            .position(x: 265, y: 125)
            
            ZStack {
                Image("Film")
                    .resizable()
                    .frame(width: 43, height: 43)
                    .rotationEffect(rotationAngle)
                    .onAppear {
                        withAnimation(animation) {
                            rotationAngle = .init(degrees: 360.0)
                        }
                    }
            }
            .position(x: 215, y: 170)
        }
        .frame(width: 300, height: 200, alignment: .center)
        .offset(x: -45, y: -10)
    }
}

struct RollingFilmsView_Previews: PreviewProvider {
    static var previews: some View {
        RollingFilmsView()
    }
}

//
//  HintReplyView.swift
//  VirtualSet
//
//  Created by Reza on 10/6/21.
//

import SwiftUI

struct HintReplyView: View {
    var width: CGFloat = 200.0
    var height: CGFloat = 50.0
    var cornerRadius: CGFloat = 5.0
    var pointerWidth: CGFloat {
        width * 0.15
    }
    
    private var pointerHeight: CGFloat {
        height * 0.3
    }
    
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        ZStack(alignment: .init(horizontal: .leading, vertical: .top)) {
            Path { path in
                path.move(to: .init(x: width, y: height))
                path.addLine(to: .init(x: width - pointerWidth, y: height - pointerHeight))
                path.addLine(to: .init(x: width - pointerWidth, y: cornerRadius))
                path.addArc(tangent1End: .init(x: width - pointerWidth, y: 0.0),
                            tangent2End: .init(x: width - pointerWidth - cornerRadius, y: 0.0),
                            radius: cornerRadius)
                path.addLine(to: .init(x: cornerRadius, y: 0))
                path.addArc(tangent1End: .init(x: 0, y: 0),
                            tangent2End: .init(x: 0, y: cornerRadius),
                            radius: cornerRadius)
                path.addLine(to: .init(x: 0, y: height - cornerRadius))
                path.addArc(tangent1End: .init(x: 0, y: height),
                            tangent2End: .init(x: cornerRadius, y: height),
                            radius: cornerRadius)
                
            }
            .fill(Color.init(red: 0.0, green: 52.0 / 255.0, blue: 98.0 / 255))
            .opacity(0.77)
            .frame(width: width, height: height)
            
            Text("OK, I see")
                .foregroundColor(.init(red: 97.0 / 255.0,
                                       green: 216.0 / 255.0,
                                       blue: 53.0 / 255.0
                                      )
                )
                .font(.system(size: 34, weight: .medium, design: .default))
                .frame(width: width - pointerWidth, height: height, alignment: .init(horizontal: .center, vertical: .center))
                //.padding([.all], 5.0)
        }
        .scaleEffect(scale)
        .onAppear {
            let animation = Animation.easeIn(duration: 0.55).delay(1.0)
            
            withAnimation(animation) {
                scale = 1.1
            }
            
            let secondAnimation = Animation.easeOut(duration: 0.55).delay(1.55)
            withAnimation(secondAnimation) {
                scale = 1.0
            }
        }
    }
}

struct HintReplyView_Previews: PreviewProvider {
    static var previews: some View {
        HintReplyView()
    }
}

//
//  DialogueView.swift
//  VirtualSet
//
//  Created by Reza on 10/5/21.
//

import SwiftUI

struct DialogueView: View {
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat = 10.0
    private var pointerWidth: CGFloat {
        width * 0.15
    }
    private var pointerHeight: CGFloat {
        height * 0.05
    }
    
    @State private var textOpacity: CGFloat = 0.0
    @State private var textScale: CGFloat = 0.0
    @State private var boxOpacity: CGFloat = 0.0
    @State private var boxScale: CGFloat = 0.0
    
    var text: String
    
    init(_ text: String, width: CGFloat = 300, height: CGFloat = 300) {
        self.text = text
        self.width = width
        self.height = height
    }
    
    var body: some View {
        ZStack(alignment: Alignment(horizontal: .leading, vertical: .top)) {
            Path { path in
                
                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: width - cornerRadius, y: 0))
                path.addArc(tangent1End: CGPoint(x: width, y: 0),
                            tangent2End: CGPoint(x: width, y: cornerRadius),
                            radius: cornerRadius)
                path.addLine(to: CGPoint(x: width, y: height - cornerRadius))
                path.addArc(tangent1End: CGPoint(x: width, y: height),
                            tangent2End: CGPoint(x: width - cornerRadius, y: height),
                            radius: cornerRadius)
                path.addLine(to: CGPoint(x: pointerWidth + cornerRadius, y: height))
                path.addArc(tangent1End: CGPoint(x: pointerWidth, y: height),
                            tangent2End: CGPoint(x: pointerWidth, y: height - cornerRadius),
                            radius: cornerRadius)
                path.addLine(to: CGPoint(x: pointerWidth, y: pointerHeight))
            }
            .fill(Color.gray.opacity(0.74))
            .frame(width: 300, height: 300)
            .scaleEffect(boxScale)
            .opacity(boxOpacity)
            .onAppear {
                let animation = Animation.easeOut(duration: 0.5)
                withAnimation(animation) {
                    boxScale = 1.0
                    boxOpacity = 1.0
                }
            }
            
            Text(text)
                .foregroundColor(.white)
                .font(.custom("SF-Pro", size: 25.0))
                .frame(width: width - pointerWidth - 10,
                       height: height,
                       alignment: Alignment(horizontal: .leading, vertical: .top))
                .padding(.leading, pointerWidth + 10.0)
                .padding(.top, 10.0)
                .shadow(radius: 3.0)
                .opacity(textOpacity)
                .scaleEffect(textScale)
                .onAppear {
                    let animation = Animation.easeOut(duration: 1.0).delay(0.5)
                    withAnimation(animation) {
                        textOpacity = 1.0
                        textScale = 1.0
                    }
                }
        }
    }
}

struct DialogueView_Previews: PreviewProvider {
    static var previews: some View {
        DialogueView("Positioning: You can  position the scene with tap, hold and drag gesture\nScale: Scale the scene larger or smaller with pinch in or out.")
    }
}

//
//  RecordView.swift
//  VirtualSet
//
//  Created by Reza on 9/4/21.
//

import SwiftUI
import os.signpost

struct RecordView: View {
    
    // MARK: - Properties
    @Binding var isRecording: Bool
    @State var isLandspace: Bool
    
    // Record Shape
    @Namespace var recordView
    var shapeID: String = "recordShape"
    
    var recordButtonStrokeStyle: StrokeStyle {
        StrokeStyle(lineWidth: 4.0, lineCap: .square, lineJoin: .miter, miterLimit: 10.0, dash: [10, 10], dashPhase: 4.0)
    }
    
    // MARK: - View
    var body: some View {
        if isLandspace {
            Button(action: {
                if !$isRecording.wrappedValue {
                    AppDelegate.orientationLock = .landscape
                } else {
                    AppDelegate.orientationLock = .all
                }
                withAnimation {
                    $isRecording.wrappedValue.toggle()
                }
            }) {
                ZStack {
                    if isRecording {
                        Rectangle()
                            .foregroundColor(.red)
                            .frame(width: 45, height: 45)
                            .scaleEffect(0.7)
                            .animation(.spring())
                    } else {
                        Capsule()
                            .foregroundColor(.red)
                            .frame(width: 50, height: 100)
                            .animation(.spring())
                    }
                    
                    Capsule()
                        .stroke(style: recordButtonStrokeStyle)
                        .foregroundColor(.white)
                        .frame(width: 55, height: 105)
                }
            }
        } else {
            Button(action: {
                if !$isRecording.wrappedValue {
                    AppDelegate.orientationLock = .portrait
                } else {
                    AppDelegate.orientationLock = .all
                }
                withAnimation {
                    $isRecording.wrappedValue.toggle()
                }
            }) {
                ZStack {
                    Rectangle()
                        .fill(Color.red)
                        .frame(width: 70, height: 70)
                        .cornerRadius(isRecording ? 0 : 35)
                        .scaleEffect(isRecording ? 0.4 : 1.0)
                        .animation(.spring())
                        .transition(.identity)
                    
                    Circle()
                        .strokeBorder(style: recordButtonStrokeStyle)
                        .frame(width: 80, height: 80)
                        .foregroundColor(.white)
                        .transition(.identity)
                }
            }
        }
    }
}

struct RecordView_Previews: PreviewProvider {
    var isRecording = false
    
    static var previews: some View {
        ZStack {
            Color.gray
                .edgesIgnoringSafeArea(.all)
            RecordView(isRecording: .constant(true),
                       isLandspace: true)
        }
    }
}

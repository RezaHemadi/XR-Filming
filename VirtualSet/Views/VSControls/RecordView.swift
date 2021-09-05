//
//  RecordView.swift
//  VirtualSet
//
//  Created by Reza on 9/4/21.
//

import SwiftUI

struct RecordView: View {
    
    // MARK: - Properties
    @Binding var isRecording: Bool
    @State var isLandspace: Bool
    
    var recordButtonStrokeStyle: StrokeStyle {
        StrokeStyle(lineWidth: 4.0, lineCap: .square, lineJoin: .miter, miterLimit: 10.0, dash: [10, 10], dashPhase: 4.0)
    }
    
    // MARK: - View
    var body: some View {
        if isLandspace {
            ZStack {
                if isRecording {
                    Rectangle()
                        .foregroundColor(.red)
                        .frame(width: 45, height: 45)
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
            .onTapGesture {
                withAnimation {
                    $isRecording.wrappedValue.toggle()
                }
            }
        } else {
            ZStack {
                if isRecording {
                    Rectangle()
                        .foregroundColor(.red)
                        .frame(width: 30, height: 30)
                        .animation(.spring())
                } else {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 70, height: 70)
                        .animation(.spring())
                }
                
                Circle()
                    .strokeBorder(style: recordButtonStrokeStyle)
                    .frame(width: 80, height: 80)
                    .foregroundColor(.white)
            }
            .onTapGesture {
                withAnimation {
                    $isRecording.wrappedValue.toggle()
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
                       isLandspace: false)
        }
    }
}

//
//  RecordView.swift
//  VirtualSet
//
//  Created by Reza on 9/4/21.
//

import SwiftUI

struct RecordView: View {
    
    var isRecording: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.red)
                .frame(width: 70, height: 70)
            
            Circle()
                .strokeBorder(style: StrokeStyle(lineWidth: 4.0, lineCap: .square, lineJoin: .miter, miterLimit: 10.0, dash: [10, 10], dashPhase: 4.0))
                .frame(width: 80, height: 80)
                .foregroundColor(.white)
            
        }
    }
}

struct RecordView_Previews: PreviewProvider {
    var isRecording = false
    
    static var previews: some View {
        RecordView(isRecording: false)
    }
}

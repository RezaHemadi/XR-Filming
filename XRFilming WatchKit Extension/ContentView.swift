//
//  ContentView.swift
//  XRFilming WatchKit Extension
//
//  Created by Reza on 11/8/21.
//  Copyright © 2021 Dynamic Stacks LTD. All rights reserved.
//

import SwiftUI
import SpriteKit
import os.signpost

struct ContentView: View {
    @EnvironmentObject var connectivity: PhoneConnectivity
    
    @State private var titleScaleFactor: CGFloat = 1.0
    @State private var handScaleFactor: CGFloat = 1.0
    @State private var doubleTapScaleFactor: CGFloat = 1.0
    private var tapGesture: some Gesture {
        TapGesture(count: 1)
            .onEnded {
                guard connectivity.state == .live else { return }
                connectivity.startRecording()
            }
    }
    private var doubleTapGesture: some Gesture {
        TapGesture(count: 2)
            .onEnded {
                guard connectivity.state == .recording else { return }
                connectivity.stopRecording()
            }
    }
    
    var liveView: some View {
        ZStack {
            feedView
            
            VStack(alignment: .center) {
                Text("Tap Anywhere To Start Recording")
                    .font(.system(size: 15.0, weight: .regular, design: .default))
                    .foregroundColor(.red)
                    .scaleEffect(titleScaleFactor)
                    .onAppear {
                        let animation: Animation = .linear(duration: 0.5).delay(1.0)
                        withAnimation(animation) {
                            titleScaleFactor = 1.2
                        }
                        
                        let secondAnimation: Animation = .linear(duration: 0.5).delay(1.5)
                        withAnimation(secondAnimation) {
                            titleScaleFactor = 1.0
                        }
                    }
                
                Spacer()
            }
            
            Image(systemName: "hand.tap.fill")
                .resizable()
                .foregroundColor(.red)
                .frame(width: 40.0, height: 40.0)
                .scaleEffect(handScaleFactor)
                .onAppear {
                    let animation: Animation = .easeInOut
                    let repeated = animation.repeatForever(autoreverses: true)
                    withAnimation(repeated) {
                        handScaleFactor = 1.2
                    }
                }
        }
        .gesture(tapGesture)
        .onAppear {
            WKExtension.shared().isAutorotating = true
        }
    }
    
    var recordView: some View {
        ZStack {
            feedView
            
            VStack {
                //TimerView(time: connectivity.time)
                
                Spacer()
                
                Text("Double Tap to End")
                    .foregroundColor(.gray)
                    .scaleEffect(doubleTapScaleFactor)
                    .onAppear {
                        let animation: Animation = .linear(duration: 0.5).delay(1.0)
                        withAnimation(animation) {
                            doubleTapScaleFactor = 1.2
                        }
                        
                        let secondAnimation: Animation = .linear(duration: 0.5).delay(1.5)
                        withAnimation(secondAnimation) {
                            doubleTapScaleFactor = 1.0
                        }
                    }
            }
            .padding()
        }
        .gesture(doubleTapGesture)
    }
    
    var videoSavedView: some View {
        ZStack {
            feedView
            
            VStack {
                Text("The Video Was Saved To Your iPhone")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.green)
                
                Spacer()
            }
            .padding()
        }
    }
    
    var feedView: some View {
        SpriteView(scene: connectivity.feed)
            .edgesIgnoringSafeArea([.bottom, .leading, .trailing])
    }
    
    var body: some View {
        switch connectivity.state {
        case .notReachable:
            Text("Waiting For iPhone Preparation")
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .padding()
            
        case .live:
            liveView
            
        case .recording:
            recordView
            
        case .videoSaved:
            videoSavedView
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(PhoneConnectivity())
    }
}

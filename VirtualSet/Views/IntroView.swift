//
//  IntroView.swift
//  VirtualSet
//
//  Created by Reza on 10/5/21.
//

import SwiftUI

struct IntroView: View {
    static let bodyFont = Font.system(size: 20, weight: .regular, design: .default)
    @EnvironmentObject var session: VSSession
    @State var isLandscape: Bool = UIDevice.current.orientation.isLandscape
    @State private var listOpacity: CGFloat = 0.0
    @State private var listScale: CGFloat = 0.0
    @State private var buttonScale: CGFloat = 1.0
    
    var body: some View {
        if !isLandscape {
            // Portrait orientation
            VStack(alignment: .center, spacing: 15) {
                Text("Light, Camera, Action")
                    .italic()
                    .font(.system(size: 28, weight: .regular, design: .default))
                    .foregroundColor(Color(.sRGB, white: 0.2, opacity: 1.0))
                    .frame(width: 300, alignment: .center)
                
                Text("This is a movie recorder app,\nso we need access to:")
                    .fontWeight(.regular)
                    .font(Self.bodyFont)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.black)
                    .frame(width: 300, alignment: .center)
                
                VStack(alignment: .leading, spacing: 15) {
                    VStack(alignment: .leading, spacing: 15) {
                        Label("Camera", systemImage: "camera.fill")
                            .font(Self.bodyFont)
                            .foregroundColor(.black)
                        
                        Label("  Microphone", systemImage: "mic.fill")
                            .font(Self.bodyFont)
                            .foregroundColor(.black)
                        
                        Label("Your gallery to save videos", systemImage: "photo.on.rectangle")
                            .font(Self.bodyFont)
                            .foregroundColor(.black)
                        
                        Label("Internet connection to download new virtual location sets", systemImage: "network")
                            .font(Self.bodyFont)
                            .foregroundColor(.black)
                    }
                    .scaleEffect(listScale)
                    .opacity(listOpacity)
                    .onAppear {
                        let animation = Animation.easeOut(duration: 1.0).delay(1.5)
                        withAnimation(animation) {
                            listScale = 1.0
                            listOpacity = 1.0
                        }
                    }
                    
                    HStack {
                        Spacer()
                        Image("ActionIcon")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 208, height: 104)
                        Spacer()
                    }
                    
                    
                    Button(action: {
                        // Ask for requiered app permissions
                        session.requestAuthorization()
                    }) {
                        Text("OK, Let's Go")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.black)
                            .padding(10.0)
                            .overlay {
                                RoundedRectangle(cornerRadius: 15)
                                            .stroke(Color.black, lineWidth: 5)
                            }
                    }
                    .frame(width: 300, alignment: .center)
                    .scaleEffect(buttonScale)
                    .onAppear {
                        let animation = Animation.easeOut(duration: 1.0)
                        let foreverAnimation = animation.repeatForever(autoreverses: true).delay(1.0)
                        withAnimation(foreverAnimation) {
                            buttonScale = 1.2
                        }
                    }
                    
                    RollingFilmsView()
                        .frame(width: 300, alignment: .center)
                }
                .frame(width: 300, alignment: .center)
            }
            .onRotate(perform: { newOrientation in
                if newOrientation.isLandscape {
                    self.isLandscape = true
                } else if newOrientation.isPortrait {
                    self.isLandscape = false
                }
            })
            
        } else {
            // Landscape orientation
            ZStack {
                HStack {
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 20.0) {
                        RollingFilmsView()
                            .scaleEffect(.init(width: -1, height: 1))
                        
                        Image("ActionIcon")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 208, height: 104)
                    }
                }
                
                VStack(spacing: 15) {
                    Text("Light, Camera, Action")
                        .italic()
                        .font(.system(size: 28, weight: .regular, design: .default))
                        .foregroundColor(Color(.sRGB, white: 0.2, opacity: 1.0))
                        .frame(width: 300, alignment: .center)
                    
                    Text("This is a movie recorder app,\nso we need access to:")
                        .fontWeight(.regular)
                        .font(Self.bodyFont)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.black)
                        .frame(width: 300, alignment: .center)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 15) {
                            Label("Camera", systemImage: "camera.fill")
                                .font(Self.bodyFont)
                                .foregroundColor(.black)
                            
                            Label("  Microphone", systemImage: "mic.fill")
                                .font(Self.bodyFont)
                                .foregroundColor(.black)
                            
                            Label("Your gallery to save videos", systemImage: "photo.on.rectangle")
                                .font(Self.bodyFont)
                                .foregroundColor(.black)
                            
                            Label("Internet connection to download new virtual location sets", systemImage: "network")
                                .font(Self.bodyFont)
                                .foregroundColor(.black)
                        }
                        .scaleEffect(listScale)
                        .opacity(listOpacity)
                        .onAppear {
                            let animation = Animation.easeOut(duration: 1.0).delay(1.5)
                            withAnimation(animation) {
                                listScale = 1.0
                                listOpacity = 1.0
                            }
                        }
                        
                        Spacer()
                    }
                    
                    
                    Button(action: {
                        // Ask for requiered app permissions
                        session.requestAuthorization()
                    }) {
                        Text("OK, Let's Go")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.black)
                            .padding(10.0)
                            .overlay {
                                RoundedRectangle(cornerRadius: 15)
                                            .stroke(Color.black, lineWidth: 5)
                            }
                    }
                    .frame(width: 250, alignment: .center)
                    .scaleEffect(buttonScale)
                    .padding([.top], 5.0)
                    .onAppear {
                        let animation = Animation.easeOut(duration: 1.0)
                        let foreverAnimation = animation.repeatForever(autoreverses: true).delay(1.0)
                        withAnimation(foreverAnimation) {
                            buttonScale = 1.2
                        }
                    }
                }
            }
            .edgesIgnoringSafeArea(UIDevice.current.orientation == .landscapeRight ? [.top, .bottom, .leading] :
                                    UIDevice.current.orientation == .landscapeLeft ? [.top, .bottom, .trailing] :
                                        .all)
            .onRotate(perform: { newOrientation in
                if newOrientation.isLandscape {
                    self.isLandscape = true
                } else if newOrientation.isPortrait {
                    self.isLandscape = false
                }
            })
        }
    }
}

struct IntroView_Previews: PreviewProvider {
    static var previews: some View {
        let deivces = ["iPhone 12 Pro Max", "iPad Pro (12.9-inch) (5th generation)"]
        ForEach(deivces, id: \.self) { deviceName in
            IntroView()
                .environmentObject(VSSession())
                .previewDevice(PreviewDevice(rawValue: deviceName))
                .previewDisplayName(deviceName)
                .previewInterfaceOrientation(.landscapeRight)
        }
    }
}

/*
 Image("ActionIcon")
     .resizable()
     .scaledToFit()
     .frame(width: 300, height: 150)
 */

/*
 
 */
/*
 
 */

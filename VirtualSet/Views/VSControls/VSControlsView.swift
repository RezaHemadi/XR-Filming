//
//  VSControlsView.swift
//  VirtualSet
//
//  Created by Reza on 9/3/21.
//

import SwiftUI
import os.signpost

struct VSControlsView: View {
    // MARK: - Properties
    @State var isLandscape = UIDevice.current.orientation.isLandscape
    var orientation: UIDeviceOrientation {
        return UIDevice.current.orientation
    }
    @State var showPhotoPicker: Bool = false
    @State var pickedImages: [UIImage] = []
    @EnvironmentObject var session: VSSession
    
    // MARK: - View
    var body: some View {
        if isLandscape {
            // Landscape Orientation
            HStack(spacing: 30){
                VStack {
                    if !session.hints.isEmpty {
                        DialogueView(session.hints.last!.text, width: 500.0, height: 200.0)
                    }
                    
                    if session.showHintReply {
                        Button(action: {
                            session.removeHint()
                        }) {
                            HintReplyView()
                        }
                    }
                }
                
                // Push left and right buttons away
                Spacer()
                
                ZStack(alignment: .center) {
                    RecordView(isRecording: $session.isRecording, isLandspace: true)
                        .scaleEffect(0.8)
                        .disabled(session.shouldShowTransformHint)
                    
                    VStack {
                        VStack {
                            if !session.isRecording {
                                Button(action: {
                                    showPhotoPicker.toggle()
                                }) {
                                    AddImageView()
                                }
                                .transition(.asymmetric(insertion: .move(edge: .top), removal: .move(edge: .top)))
                                .animation(.easeInOut(duration: 0.3))
                                .disabled(session.shouldShowTransformHint)
                            }
                            
                            Button(action: {
                                session.takePhoto()
                            }) {
                                SnapshotView()
                            }
                            .disabled(session.shouldShowTransformHint)
                        }
                        .frame(height: 200, alignment: .bottom)
                        .offset(y: -70)
                        
                        Spacer()
                    }
                    
                    VStack() {
                        Spacer()
                        
                        VStack {
                            if !session.isRecording {
                                Button(action: {
                                    withAnimation {
                                        session.state = .pickingSet
                                    }
                                }) {
                                    ChangeSceneView()
                                }
                                .transition(.asymmetric(insertion: .move(edge: .bottom), removal: .move(edge: .bottom)))
                                .animation(.easeInOut(duration: 0.3))
                                .disabled(session.shouldShowTransformHint)
                            }
                            
                            if !session.isRecording {
                                Button(action: { session.resetTracking() }) {
                                    Image("Reset")
                                        .resizable()
                                        .frame(width: 50.0, height: 50.0, alignment: .center)
                                }
                                .transition(.asymmetric(insertion: .move(edge: .bottom), removal: .move(edge: .bottom)))
                                .animation(.easeInOut(duration: 0.3))
                                .disabled(session.shouldShowTransformHint)
                            }
                        }
                        .frame(height: 200, alignment: .top)
                        .offset(y: 70)
                        
                        
                    }
                }
                .frame(width: 50, height: min(400 - 15, UIScreen.main.bounds.height - 15))
                .background {
                    Rectangle()
                        .fill(Color.init(white: 0.25).opacity(0.6))
                        .frame(width: 70.0, height: min(350 - 15, UIScreen.main.bounds.height - 15))
                        .cornerRadius(15.0)
                }
            }
            .padding(.trailing, 20.0)
            .edgesIgnoringSafeArea(orientation == .landscapeLeft ? .all : [.bottom, .top, .leading])
            .onRotate { newOrientation in
                guard AppDelegate.orientationLock == .all else { return }
                if newOrientation.isLandscape {
                    self.isLandscape = true
                } else if newOrientation.isPortrait {
                    self.isLandscape = false
                }
            }
            .sheet(isPresented: $showPhotoPicker) {
                PhotoPicker(isPresented: $showPhotoPicker)
                    .environmentObject(session)
            }
        } else {
            // Portrait Orientation
            VStack {
                if !session.isDeviceSupported {
                    HStack {
                        Spacer()
                        Button(action: { session.showDeviceNotSupportedHint(delay: 0.0) }) {
                            Image(systemName: "info.circle.fill")
                                .resizable()
                                .foregroundColor(.red)
                                .frame(width: 25.0, height: 25.0)
                        }
                    }
                    .padding()
                }
                VStack(spacing: 40){
                    if !session.hints.isEmpty {
                        HStack {
                            DialogueView(session.hints.last!.text, width: 300, height: 300)
                            Spacer()
                        }
                        .padding(.leading, 20)
                    }
                    Spacer()
                    // Vertical stack containing hint reply and bottom record and controls
                    VStack(alignment: .center, spacing: 60.0) {
                        if session.showHintReply {
                            Button(action: {
                                session.removeHint()
                            }) {
                                HintReplyView()
                            }
                        }
                        // Bottom Screen Controls
                        ZStack(alignment: .bottom) {
                            RecordView(isRecording: $session.isRecording, isLandspace: false)
                                .disabled(session.shouldShowTransformHint)
                            
                            HStack() {
                                
                                HStack(spacing: 15.0) {
                                    if !session.isRecording {
                                        Button(action: { session.resetTracking() }) {
                                            Image("Reset")
                                                .resizable()
                                                .frame(width: 50.0, height: 50.0, alignment: .center)
                                        }
                                        .transition(.asymmetric(insertion: .slide, removal: .move(edge: .leading)))
                                        .animation(.easeInOut(duration: 0.3))
                                        .disabled(session.shouldShowTransformHint)
                                    }
                                    
                                    if !session.isRecording {
                                        Button(action: {
                                            withAnimation {
                                                session.state = .pickingSet
                                            }
                                        }) {
                                            ChangeSceneView()
                                        }
                                        .transition(.asymmetric(insertion: .slide, removal: .move(edge: .leading)))
                                        .animation(.easeInOut(duration: 0.3))
                                        .disabled(session.shouldShowTransformHint)
                                    }
                                }
                                .frame(width: 400.0 / 2, height: 80, alignment: .trailing)
                                .offset(x: -60)
                                
                                Spacer()
                                
                            }
                            
                            HStack() {
                                Spacer()
                                
                                HStack(spacing: 25.0) {
                                    Button(action:
                                            {
                                                session.takePhoto()
                                                
                                    }) {
                                        SnapshotView()
                                    }
                                    .disabled(session.shouldShowTransformHint)
                                    
                                    if !session.isRecording {
                                        Button(action: {
                                            showPhotoPicker.toggle()
                                        }) {
                                            AddImageView()
                                        }
                                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .trailing)))
                                        .animation(.easeInOut(duration: 0.3))
                                        .disabled(session.shouldShowTransformHint)
                                    }
                                }
                                .frame(width: 400.0 / 2, height: 80, alignment: .leading)
                                .offset(x: 60.0)
                            }
                            
                        }
                        .frame(width: min(400.0, UIScreen.main.bounds.width))
                        .background {
                            Rectangle()
                                .fill(Color.init(white: 0.25).opacity(0.6))
                                .frame(width: min(400.0 - 15.0, UIScreen.main.bounds.width - 15.0), height: 50.0)
                                .cornerRadius(15.0)
                        }
                    }
                }
                .edgesIgnoringSafeArea([.leading, .trailing])
                .padding([.bottom], 20.0)
                .onRotate { newOrientation in
                    guard AppDelegate.orientationLock == .all else { return }
                    if newOrientation.isLandscape {
                        self.isLandscape = true
                    } else if newOrientation.isPortrait {
                        self.isLandscape = false
                    }
                }
                .sheet(isPresented: $showPhotoPicker) {
                    PhotoPicker(isPresented: $showPhotoPicker)
                        .environmentObject(session)
            }
            }
        }
    }
}

struct VSControlsView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Image("Dome")
                .resizable()
                .scaledToFill()
                .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height, alignment: .center)
            
            VSControlsView()
                .environmentObject(VSSession())
        }
    }
}

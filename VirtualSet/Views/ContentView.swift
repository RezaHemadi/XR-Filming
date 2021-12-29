//
//  ContentView.swift
//  VirtualSet
//
//  Created by Reza on 9/3/21.
//

import SwiftUI
import RealityKit
import SpriteKit
import os.signpost

struct ContentView : View {
    // MARK: - Properties
    @EnvironmentObject var session: VSSession
    static let backgroundGray: Color = Color(white: 70.0/255.0)
    
    var dimBackground: Bool {
        switch session.state {
        case .initializing, .pickingSet, .loadingModel:
            return true
        case .exploringScene:
            return false
        }
    }
    
    var shouldRecognizeTransformGestures: Bool {
        switch session.state {
        case .exploringScene:
            return true
        default:
            return false
        }
    }
    
    enum RotateAndScaleState {
        case inactive
        case active
    }
    
    @GestureState var gestureState: RotateAndScaleState = .inactive
    @GestureState var tapGestureState = true
    
    var longTapGesture: some Gesture {
        LongPressGesture()
            .onEnded { _ in
                session.longPressed = true
            }
    }
    
    var body: some View {
        let rotateAndScale = RotationGesture().simultaneously(with: MagnificationGesture())
            .updating($gestureState) { gestureValue, state, transaction in
                guard shouldRecognizeTransformGestures else { return }
                
                if let angle = gestureValue.first, let magnification = gestureValue.second {
                    session.rotateAndScale(angle: angle, magnitude: magnification)
                }
                
            }
        
        if !session.isAuthorized {
            ZStack {
                Color.white
                    .edgesIgnoringSafeArea(.all)
                IntroView()
                    .environmentObject(session)
                    .edgesIgnoringSafeArea([.top, .bottom, .trailing])
            }
        } else {
            ZStack {
                ARViewContainer(session: session)
                    .edgesIgnoringSafeArea(.all)
                    .gesture(
                        DragGesture(minimumDistance: 0.0, coordinateSpace: .local)
                            .onChanged({ value in
                                guard shouldRecognizeTransformGestures else { return }
                                
                                let dy = abs(value.translation.height)
                                let dx = abs(value.translation.width)
                                
                                guard !dy.isLess(than: 10.0) && !dx.isLess(than: 10.0) else { return }
                                
                                session.translateSet(value: value)
                                
                                
                            })
                            .onEnded({ endValue in
                                guard shouldRecognizeTransformGestures else { return }
                                
                                let dy = abs(endValue.translation.height)
                                let dx = abs(endValue.translation.width)
                                
                                if dx.isLess(than: 10.0) && dy.isLess(than: 10.0) {
                                    session.handleTap(location: endValue.location)
                                } else {
                                    session.commitTranslation(endValue: endValue)
                                }
                            })
                            .simultaneously(with: longTapGesture)
                    )
                    .gesture(rotateAndScale)
                    .onAppear(perform: { UIApplication.shared.isIdleTimerDisabled = true })
                
                MainView()
                    .environmentObject(session)
                
                if session.announcement != nil {
                    AnnouncementView(session.announcement!)
                }
                
                ARCoachingViewContainer(session: session)
                    .allowsHitTesting(session.allowCoachingViewHitTesting)
                    .edgesIgnoringSafeArea(.all)
                    .padding(.bottom, 30.0)
            }
            .background(Self.backgroundGray)
        }
    }
}

#if DEBUG
struct ContentView_Previews : PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(VSSession())
            .previewDevice(PreviewDevice(rawValue: "iPhone 12 Pro Max"))
            .previewDisplayName("iPhone 12 Pro Max")
    }
}
#endif

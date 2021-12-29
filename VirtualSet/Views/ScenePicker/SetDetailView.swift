//
//  SetDetailView.swift
//  VirtualSet
//
//  Created by Reza on 9/11/21.
//

import SwiftUI

struct SetDetailView: View {
    @State private var currentUIOrientation: UIOrientation = .init(deviceOrientation: UIDevice.current.orientation)
    
    var detailViewTransition: AnyTransition {
        let insertion = AnyTransition.slide.animation(.easeOut)
        let removal: AnyTransition
        
        switch currentUIOrientation {
        case .landscape:
            removal = AnyTransition.offset(x: UIScreen.main.bounds.width, y: 0).animation(.easeIn).combined(with: .opacity).animation(.easeIn.delay(1.0))
        case .portrait:
            removal = AnyTransition.offset(x: 0, y: UIScreen.main.bounds.height / 2.0).animation(.easeIn).combined(with: .opacity).animation(.easeIn.delay(1.0))
        }
        
        return .asymmetric(insertion: insertion, removal: removal)
    }
    
    var set: SetPreview
    @State var duration: Double = 0.2
    
    var body: some View {
        VStack(alignment: .leading){
            Text(set.name)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
            Text(set.description)
                .font(.body)
                .foregroundColor(.white)
        }
        .animation(.easeInOut(duration: duration))
        .transition(detailViewTransition)
        .onAppear {
            duration = 3.0
        }
    }
}

struct SetDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let deivces = ["iPhone 12 Pro Max", "iPad Pro (12.9-inch) (5th generation)"]
        ForEach(deivces, id: \.self) { deviceName in
            ZStack {
                Image("Dome")
                    .resizable()
                    .scaledToFill()
                    .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height, alignment: .center)
                SetDetailView(set: VSSession().setPreviews[0])
            }
            .previewDevice(PreviewDevice(rawValue: deviceName))
            .previewDisplayName(deviceName)
        }
    }
}

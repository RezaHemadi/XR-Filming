//
//  DeviceRotationViewModifier.swift
//  VirtualSet
//
//  Created by Reza on 9/4/21.
//

import Foundation
import SwiftUI

/// - Tag: View Modifier To Track Rotation And Call Our Action
struct DeviceRotationViewModifier: ViewModifier {
    let action: (UIDeviceOrientation) -> Void
    
    func body(content: Content) -> some View {
        content
            .onAppear()
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                action(UIDevice.current.orientation)
            }
    }
}

/// - Tag: View Wrapper to make it easier to use DeviceRotationViewModifer
extension View {
    func onRotate(perform action: @escaping (UIDeviceOrientation) -> Void) -> some View {
        self.modifier(DeviceRotationViewModifier(action: action))
    }
}

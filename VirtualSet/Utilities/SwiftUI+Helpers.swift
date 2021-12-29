//
//  SwiftUI+Helpers.swift
//  VirtualSet
//
//  Created by Reza on 10/3/21.
//

import Foundation
import SwiftUI

enum UIOrientation {
    case landscape
    case portrait
    
    init(deviceOrientation: UIDeviceOrientation) {
        switch deviceOrientation {
        case .unknown:
            self = .portrait
        case .portrait:
            self = .portrait
        case .portraitUpsideDown:
            self = .portrait
        case .landscapeLeft:
            self = .landscape
        case .landscapeRight:
            self = .landscape
        case .faceUp:
            self = .portrait
        case .faceDown:
            self = .portrait
        }
    }
}

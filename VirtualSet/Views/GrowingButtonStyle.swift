//
//  GrowingButtonStyle.swift
//  VirtualSet
//
//  Created by Reza on 12/29/21.
//  Copyright © 2021 Dynamic Stacks LTD. All rights reserved.
//

import Foundation
import SwiftUI

struct GrowingButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 1.2 : 1)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

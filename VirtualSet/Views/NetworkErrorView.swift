//
//  NetworkErrorView.swift
//  VirtualSet
//
//  Created by Reza on 11/8/21.
//  Copyright © 2021 Dynamic Stacks LTD. All rights reserved.
//

import SwiftUI

struct NetworkErrorView: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 15.0)
                .fill(.red)
            Text("Unable To Download Check Your Internet Connection")
                .foregroundColor(.white)
                .font(.system(size: 17.0, weight: .bold, design: .default))
                .multilineTextAlignment(.center)
        }
    }
}

struct NetworkErrorView_Previews: PreviewProvider {
    static var previews: some View {
        NetworkErrorView()
    }
}

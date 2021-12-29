//
//  TimerView.swift
//  XRFilming WatchKit Extension
//
//  Created by Reza on 11/11/21.
//  Copyright © 2021 Dynamic Stacks LTD. All rights reserved.
//

import SwiftUI

struct TimerView: View {
    var time: TimeInterval
    
    var formattedTime: String {
        let min = Int(time / 60.0)
        let sec = Int(time.truncatingRemainder(dividingBy: 60.0))
        
        var minString: String = ""
        var secString: String = ""
        
        if min < 10 {
            minString = "0" + String(min)
        } else {
            minString = String(min)
        }
        
        if sec < 10 {
            secString = "0" + String(sec)
        } else {
            secString = String(sec)
        }
        
        return minString + ":" + secString
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10.0)
                .fill(.red)
                .opacity(0.7)
            
            Text(formattedTime)
                .foregroundColor(.gray)
        }
        .frame(width: 60, height: 30)
    }
}

struct TimerView_Previews: PreviewProvider {
    static var previews: some View {
        TimerView(time: 8.0)
            .background(Color.blue)
    }
}

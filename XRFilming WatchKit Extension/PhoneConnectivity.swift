//
//  PhoneConnectivity.swift
//  XRFilming WatchKit Extension
//
//  Created by Reza on 11/8/21.
//  Copyright © 2021 Dynamic Stacks LTD. All rights reserved.
//

import Foundation
import WatchConnectivity
import AVFoundation
import os.signpost
import UIKit
import SwiftUI

class PhoneConnectivity: NSObject, ObservableObject {
    // MARK: - Types
    enum State {
        case notReachable
        case live
        case recording
        case videoSaved
    }
    
    // MARK: - Properties
    var session: WCSession
    @Published var state: State = .notReachable
    var uiImage: UIImage?
    var width: Int?
    var height: Int?
    @Published var time: TimeInterval = 0.0
    @Published var frameCounter: Int = 0
    var currentMessageData: Data?
    var feed: VideoFeedScene
    var cgImage: CGImage?
    
    // MARK: - Initialization
    override init() {
        session = WCSession.default
        feed = VideoFeedScene(size: .init(width: 200.0, height: 200.0))
        
        super.init()
        
        session.delegate = self
        session.activate()
    }
    
    // MARK: - Methods
    func updateImage() {
        let bytesPerRow = width! * 32
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let callBack: CGDataProviderReleaseDataCallback = { _ , _ , _ in }
        let provider = CGDataProvider.init(dataInfo: nil, data: &currentMessageData!, size: currentMessageData!.count, releaseData: callBack)!
        cgImage = CGImage(width: width!, height: height!, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: .floatComponents, provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }
    func startRecording() {
        guard session.isReachable else { return }
        
        // Send Record Command
        let command: [String: Any] = [SyncCommand.record.rawValue: ""]
        session.sendMessage(command, replyHandler: nil) { error in
            os_log(.error, "error sending record command to iPhone: %s", "\(error)")
        }
    }
    
    func stopRecording() {
        guard session.isReachable else { return }
        
        // Send stop command
        let command: [String: Any] = [SyncCommand.stop.rawValue: ""]
        session.sendMessage(command, replyHandler: nil) { error in
            os_log(.error, "error sending stop recording message to iPhone: %s", "\(error)")
        }
    }
    
    // MARK: - Helper Methods
    private func requestSessionStatus() {
        session.sendMessage([SyncCommand.status.rawValue: ""], replyHandler: nil) { [weak self] error in
            // Retry
            let when = DispatchTime.now() + 5.0
            DispatchQueue.main.asyncAfter(deadline: when) {
                self?.requestSessionStatus()
            }
        }
    }
    
    private func handleReceivedStatusCommnad(status: SyncCommand.Status) {
        var state: PhoneConnectivity.State?
        switch status {
        case .preparing:
            state = .notReachable
        case .viewing:
            state = .live
        case .recording:
            state = .recording
        }
        
        if let receivedState = state {
            DispatchQueue.main.async {
                self.state = receivedState
            }
        }
    }
    
    private func requestDimensions() {
        let message: [String: Any] = [SyncCommand.dimension.rawValue: ""]
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil) { error in
                os_log(.error, "error sending dimension request: %s", "\(error)")
            }
        }
    }
}

extension PhoneConnectivity: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        switch activationState {
        case .notActivated:
            os_log(.info, "watch session not activated")
        case .inactive:
            os_log(.info, "watch session is inactive")
        case .activated:
            os_log(.info, "watch session activated")
        }
    }
    
    func session(_ session: WCSession, didReceiveMessageData messageData: Data) {
        switch state {
        case .live, .recording, .videoSaved:
            DispatchQueue.main.async {
                self.currentMessageData = messageData
                
                self.frameCounter += 1
                
                self.feed.updateTexture(messageData)
            }
        default:
            break
        }
        
        
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        os_log(.info, "received message: \n%s", "\(message)")
        for (key, value) in message {
            if let command = SyncCommand(rawValue: key) {
                switch command {
                case .status:
                    if let statusValue = SyncCommand.Status.init(rawValue: value as! Int) {
                        handleReceivedStatusCommnad(status: statusValue)
                    }
                    
                case .width:
                    if let width = value as? Int {
                        self.width = width
                        feed.width = width
                    }
                    
                case .height:
                    if let height = value as? Int {
                        self.height = height
                        feed.height = height
                    }
                    
                case .elapsed:
                    if let elapsed = value as? Double {
                        DispatchQueue.main.async {
                            self.time = elapsed
                        }
                    }
                    
                case .videoSaved:
                    DispatchQueue.main.async {
                        self.state = .videoSaved
                    }
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 3.0) {
                        self.requestSessionStatus()
                    }
                    
                case .stop, .record, .dimension:
                    break
                }
            }
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        os_log(.info, "iPhone reachability did change: %s", "\(session.isReachable)")
        if !session.isReachable {
            state = .notReachable
        } else {
            // Request session state from iPhone
            requestSessionStatus()
        }
    }
}

//
//  WatchSession.swift
//  VirtualSet
//
//  Created by Reza on 11/8/21.
//  Copyright © 2021 Dynamic Stacks LTD. All rights reserved.
//

import Foundation
import WatchConnectivity
import os.signpost
import Metal
import AVFoundation

// MARK: - Types
protocol WatchSessionDataSource: AnyObject {
    func currentState() -> VSSession.SessionState
}

protocol WatchSessionDelegate: AnyObject {
    func watchSessionDidReceiveRecordCommand(_ watchSession: WatchSession)
    func watchSessionDidReceiveStopCommand(_ watchSession: WatchSession)
    func watchSessionReachabilityChanged(_ watchSession: WatchSession)
}

/// - Tag: WatchSession
class WatchSession: NSObject {
    // MARK: - Properties
    var session: WCSession
    weak var dataSource: WatchSessionDataSource?
    weak var delegate: WatchSessionDelegate?
    
    private var width: Int?
    private var height: Int?
    
    
    // MARK: - Initialization
    override init() {
        session = WCSession.default
        super.init()
        
        session.delegate = self
        session.activate()
    }
    
    // MARK: - Methods
    func update(texture: MTLTexture, elapsed: TimeInterval?) {
        let height = texture.height / 32
        let width = texture.width / 32
        let bytesPerRow = 4 * width
        let bytesCount = bytesPerRow * height
        
        let bytes = UnsafeMutableRawPointer.allocate(byteCount: bytesCount, alignment: 4)
        let region = MTLRegionMake2D(0, 0, width, height)
        texture.getBytes(bytes, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 5)
        let data = Data.init(bytes: bytes, count: bytesCount)
        
        if session.isReachable {
            os_log(.info, "watch is reachable")
            os_log(.info, "sending data to watch with size: %s", "\(data.count)")
            session.sendMessageData(data, replyHandler: nil) { error in
                os_log(.error, "error sending message to watch: %s", "\(error)")
            }
            /*
            if let elapsed = elapsed {
                let message: [String: Double] = [SyncCommand.elapsed.rawValue: elapsed]
                session.sendMessage(message, replyHandler: nil) { error in
                    os_log(.error, "error sending elapsed command to watch: %s", "\(error)")
                }
            }*/
        } else {
            os_log(.info, "watch is not reachable, unable to send data")
        }
    }
    
    func sendVideoSavedCommand() {
        let command: [String: Any] = [SyncCommand.videoSaved.rawValue: ""]
        if session.isReachable {
            session.sendMessage(command, replyHandler: nil) { error in
                os_log(.error, "error sending video saved command to watch: %s", "\(error)")
            }
        }
    }
    
    func sendDimensionUpdate(width: Int, height: Int) {
        self.width = width
        self.height = height
        
        guard session.isReachable else { return }
        let widthCommand: [String: Int] = [SyncCommand.width.rawValue: width]
        let heightCommand: [String: Int] = [SyncCommand.height.rawValue: height]
        
        session.sendMessage(widthCommand, replyHandler: nil) { error in
            os_log(.error, "error sending width command: %s", "\(error)")
        }
        
        session.sendMessage(heightCommand, replyHandler: nil) { error in
            os_log(.error, "error sending height command: %s", "\(error)")
        }
    }
    
    func broadcastStatusChange(_ status: VSSession.SessionState) {
        guard session.isReachable else { os_log(.info, "could not broadcast status change to watch. watch is not reachable"); return }
        
        os_log(.info, "broadcasting status change to watch: %s", "\(status)")
        
        var message: [SyncCommand: SyncCommand.Status]?
        
        switch status {
            
        case .initializing:
            message = [.status: .preparing]
        case .pickingSet:
            message = [.status: .preparing]
        case .exploringScene(let exploringState):
            switch exploringState {
            case .viewing:
                message = [.status: .viewing]
            case .recording:
                message = [.status: .recording]
            }
        case .loadingModel:
            message = [.status: .viewing]
        }
        if message != nil {
            if let reply = message!.compactMap({ [$0.key.rawValue: $0.value.rawValue] }).first {
                session.sendMessage(reply, replyHandler: nil) { error in
                    os_log(.error, "error sending status message to watch: %s", "\(error)")
                }
            }
        }
    }
    
    func replyStatusRequest() {
        guard session.isReachable else { return }
        
        var reply: [String: Any]?
        if let currentState = dataSource?.currentState() {
            switch currentState {
            case .initializing, .loadingModel, .pickingSet:
                reply = [SyncCommand.status.rawValue: SyncCommand.Status.preparing.rawValue]
            case .exploringScene(let exploringState):
                switch exploringState {
                case .viewing:
                    reply = [SyncCommand.status.rawValue: SyncCommand.Status.viewing.rawValue]
                case .recording:
                    reply = [SyncCommand.status.rawValue: SyncCommand.Status.recording.rawValue]
                }
            }
        } else {
            os_log(.error, "could not determine current state. data source on watch session probably not set")
        }
        
        if let reply = reply {
            session.sendMessage(reply, replyHandler: nil) { error in
                os_log(.error, "error sending message to watch: %s", "\(error)")
            }
        }
    }
    
    func handleRecordCommand() {
        delegate?.watchSessionDidReceiveRecordCommand(self)
    }
    
    func handleStopRecordingcCommand() {
        delegate?.watchSessionDidReceiveStopCommand(self)
    }
}

extension WatchSession: WCSessionDelegate {
    func sessionReachabilityDidChange(_ session: WCSession) {
        delegate?.watchSessionReachabilityChanged(self)
        if session.isReachable, let status = dataSource?.currentState() {
            broadcastStatusChange(status)
        }
    }
    func sessionDidBecomeInactive(_ session: WCSession) {
        os_log(.info, "watch session did become inactive")
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        os_log(.info, "watch session did deactivate")
    }
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        os_log(.info, "watch session did activate")
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        for (key, _) in message {
            if let command = SyncCommand.init(rawValue: key) {
                switch command {
                case .status:
                    // Respond with current status
                    replyStatusRequest()
                    
                case .record:
                    // Record Command Received from watch
                    handleRecordCommand()
                    
                case .stop:
                    // Stop Recording Command Received from Watch
                    handleStopRecordingcCommand()
                    
                case .dimension:
                    // Handle dimension request
                    guard session.isReachable, let width = self.width, let height = self.height else { return }
                    
                    let widthCommand: [String: Int] = [SyncCommand.width.rawValue: width]
                    let heightCommand: [String: Int] = [SyncCommand.height.rawValue: height]
                    
                    session.sendMessage(widthCommand, replyHandler: nil) { error in
                        os_log(.error, "error sending width command: %s", "\(error)")
                    }
                    
                    session.sendMessage(heightCommand, replyHandler: nil) { error in
                        os_log(.error, "error sending height command: %s", "\(error)")
                    }
                    
                case .width, .height, .elapsed, .videoSaved:
                    break
                }
            }
        }
    }
}

//
//  Recorder.swift
//  VirtualSet
//
//  Created by Reza on 9/6/21.
//

import Foundation
import AVFoundation
import ARKit
import Combine
import RealityKit
import os.signpost
import QuartzCore
import CoreGraphics

/// - Tag: Recorder Object responsible for recording video of AR Session
class Recorder {
    // MARK: - Properties
    
    /// object that writes video frames to output url
    private var writer: AVAssetWriter!
    
    /// input for media writer
    private var writerInput: AVAssetWriterInput!
    
    /// output url of recorded video
    var outputURL: URL?
    
    /// var to keep track of recording status
    private var isRecording: Bool = false {
        didSet {
            guard oldValue != isRecording else { return }
            
            if isRecording {
                startRecording()
            } else {
                stopRecording()
            }
        }
    }
    
    /// array holding publisher streams
    private var streams = [AnyCancellable]()
    
    /// Pixedl Buffer Adoptor Holding Pixel Buffers and Feeding Them To Writer Input
    private var adoptor: AVAssetWriterInputPixelBufferAdaptor!
    
    /// AR View To Record Video of
    var arView: ARView
    
    /// Video Resolution To Record
    private lazy var size: CGSize = {
        let viewSize = arView.bounds.size
        return CGSize(width: viewSize.width, height: viewSize.height)
    }()
    
    /// Frame Count of AR Session Frames since AR Session started
    var frameCount: Int = 0
    
    /// Keep Track Of Recorded Frame Count
    var videoFrame: Int = 1
    
    // MARK: - Initialization
    init(view: ARView, isRecording: Published<Bool>.Publisher) {
        self.arView = view
        outputURL = makeOutputURL(fileName: "myMovie.mov")
        setupWriter()
        subscribeToIsRecording(isRecording: isRecording)
    }
    
    // MARK: - Methods
    
    /// Subscribe to Client's isRecording Publisheer to Start Recording or Stop Once it's Toggled
    private func subscribeToIsRecording(isRecording: Published<Bool>.Publisher) {
        let stream = isRecording.sink { isRecording in
            self.isRecording = isRecording
        }
        stream.store(in: &streams)
    }
    
    /// Create URL To Output Video Recording To
    private func makeOutputURL(fileName: String) -> URL? {
        do {
            var cachesDirectory: URL = try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            cachesDirectory.appendPathComponent(fileName)
            if FileManager.default.fileExists(atPath: cachesDirectory.path) {
                try FileManager.default.removeItem(atPath: cachesDirectory.path)
            }
            return cachesDirectory
        } catch {
            os_log(.error,"error creating directory: %s", "\(error.localizedDescription)")
            return nil
        }
    }
    
    /// Setup Video Writer and Video Input Settings
    private func setupWriter() {
        writer = try! AVAssetWriter(outputURL: outputURL!, fileType: AVFileType.mov)
        let outputSettings: [String: Any] = [AVVideoCodecKey: AVVideoCodecType.h264,
                                             AVVideoWidthKey: size.width,
                                             AVVideoHeightKey: size.height]
        writerInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: outputSettings)

        let bufferAttribs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey as String: size.width,
            kCVPixelBufferHeightKey as String: size.height
        ]
        adoptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: writerInput, sourcePixelBufferAttributes: bufferAttribs)
        writer.add(writerInput)
        writerInput.expectsMediaDataInRealTime = true
        
        guard writer != nil, writerInput != nil, adoptor != nil else { fatalError("could not initialize writer assets")}
    }
    
    /// Start Recording Video
    private func startRecording() {
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)
    }
    
    /// Stop Recording Video
    private func stopRecording() {
        writerInput.markAsFinished()
        writer.finishWriting {
            UISaveVideoAtPathToSavedPhotosAlbum(self.outputURL!.path, nil, nil, nil)
        }
    }
    
    /// Called By The Client Every Time A new AR Frame is Processed By The Graphics Renderer
    func update(_ frame: ARFrame) {
        guard isRecording else { return }
        
        self.frameCount += 1
        
        guard (frameCount % 2) != 0 else { return }
        
        os_log(.info, "capturing snapshot with size: %s, at frame: %s", "\(size)", "\(frameCount)")
        DispatchQueue.main.async {
            UIGraphicsBeginImageContextWithOptions(self.size, true, 0)
            self.arView.drawHierarchy(in: CGRect(x: 0, y: 0, width: self.size.width, height: self.size.height), afterScreenUpdates: false)
            let snapshot = UIGraphicsGetImageFromCurrentImageContext()!
            UIGraphicsEndImageContext()
            let buffer = snapshot.cgImage!.makePixelBuffer()!
            
            let timeScale = CMTimeScale(30)
            let presentationTime = CMTime(value: CMTimeValue(self.videoFrame), timescale: timeScale)
            let success = self.adoptor.append(buffer, withPresentationTime: presentationTime)
            self.videoFrame += 1
            os_log(.info, "pixel buffer insertion status: %s", "\(success)")
        }
    }
}

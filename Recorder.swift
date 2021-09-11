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

enum RecorderError: Error {
    case pixelBufferError(description: String, status: CVReturn)
}

/// - Tag: Recorder Object responsible for recording video of AR Session
class Recorder: NSObject {
    
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
    
    /// Audio Capture Session Using The Built-in Microphone
    private var audioCaptureSession: AVCaptureSession!
    
    /// Audio Output Used Writer
    private var audioOutput: AVCaptureAudioDataOutput!
    
    /// Audio Track Input of Recording
    private var audioAssetWriterInput: AVAssetWriterInput!
    
    /// Frame Count of AR Session Frames since AR Session started
    var frameCount: Int = 0
    
    /// Keep Track Of Recorded Frame Count
    var videoFrame: Int = 1
    
    var pixelBuffer: CVPixelBuffer?
    var pixelBytesPerRow: Int = 0
    var queue: DispatchQueue = DispatchQueue.init(label: "myQueue")
    var startedAt: Double?
    var elapsed: Double = 0
    
    // MARK: - Initialization
    init?(view: ARView, isRecording: Published<Bool>.Publisher) {
        self.arView = view
        super.init()
        
        createDisplayLink()
        
        outputURL = makeOutputURL(fileName: "myMovie.mov")
        subscribeToIsRecording(isRecording: isRecording)
        do {
            try setupPixelBuffer()
        } catch {
            return nil
        }
        setupWriter()
    }
    
    // MARK: - Methods
    private func setupPixelBuffer() throws {
        let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(size.width), Int(size.height), kCVPixelFormatType_32BGRA, nil, &self.pixelBuffer)
        guard status == kCVReturnSuccess else {
            throw RecorderError.pixelBufferError(description: "failed to initialize pixel buffer.", status: status)
        }
        pixelBytesPerRow = CVPixelBufferGetBytesPerRow(self.pixelBuffer!)
    }
    
    func createDisplayLink() {
        let displaylink = CADisplayLink(target: self,
                                        selector: #selector(step))
        displaylink.add(to: .current,
                        forMode: RunLoop.Mode.default)
    }
    
    @objc
    func step(displaylink: CADisplayLink) {
        guard isRecording else { return }
        if startedAt == nil {
            startedAt = displaylink.timestamp
        }
        frameCount += 1
        //guard (frameCount % 2) == 0 else { return }
        
        DispatchQueue.main.async { [self] in
            UIGraphicsBeginImageContext(size)
            let rect = arView.bounds
            arView.drawHierarchy(in: rect, afterScreenUpdates: false)
            let image = UIGraphicsGetImageFromCurrentImageContext()!
            UIGraphicsEndImageContext()
            let buffer = image.cgImage!.makePixelBuffer()
            elapsed = displaylink.timestamp - startedAt!
            let scale = CMTimeScale(NSEC_PER_SEC)
            let presentationTime = CMTime(value: CMTimeValue(elapsed * Double(scale)), timescale: scale)
            adoptor.append(buffer!, withPresentationTime: presentationTime)
        }
    }
    
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
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: size.width,
            kCVPixelBufferHeightKey as String: size.height
        ]
        adoptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: writerInput, sourcePixelBufferAttributes: bufferAttribs)
        writer.add(writerInput)
        writerInput.expectsMediaDataInRealTime = true
        
        let audioOutputSettings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVLinearPCMIsNonInterleaved:false,
            AVSampleRateKey: 44_100.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMIsBigEndianKey: 0,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMBitDepthKey: 16
        ]
        audioAssetWriterInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioOutputSettings)
        audioAssetWriterInput.expectsMediaDataInRealTime = true
        writer.add(audioAssetWriterInput)
        
        guard writer != nil, writerInput != nil, adoptor != nil else { fatalError("could not initialize writer assets")}
    }
    
    /// Start Recording Video
    private func startRecording() {
        startAudioCapture()
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)
    }
    
    /// Stop Recording Video
    private func stopRecording() {
        self.audioAssetWriterInput.markAsFinished()
        queue.async { [self] in
            writerInput.markAsFinished()
            writer.finishWriting {
                        UISaveVideoAtPathToSavedPhotosAlbum(self.outputURL!.path, self, #selector(self.videoSaveCompletion(video:didFinishSavingWithError:contextInfo:)), nil)
            }
        }
    }
    
    @objc
    func videoSaveCompletion(video: NSString, didFinishSavingWithError: NSError?, contextInfo: UnsafeRawPointer?) {
        self.outputURL = self.makeOutputURL(fileName: "myMovie.mov")
        self.setupWriter()
        startedAt = nil
        self.videoFrame = 0
    }
    
    private func startAudioCapture() {
        audioCaptureSession = AVCaptureSession()
        let captureDevice = AVCaptureDevice.default(for: .audio)!
        do {
            let audioInput = try AVCaptureDeviceInput(device: captureDevice)
            audioCaptureSession.addInput(audioInput)
            audioOutput = AVCaptureAudioDataOutput()
            audioOutput.setSampleBufferDelegate(self, queue: DispatchQueue.main)
            audioCaptureSession.addOutput(audioOutput)
            audioCaptureSession.startRunning()
        } catch {
            os_log(.error, "error setting up audio input")
        }
    }
}

extension Recorder: AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard isRecording else { return }
        
        var count: CMItemCount = 0
        CMSampleBufferGetSampleTimingInfoArray(sampleBuffer, entryCount: count, arrayToFill: nil, entriesNeededOut: &count)
        var info = [CMSampleTimingInfo](repeating: CMSampleTimingInfo(duration: CMTimeMake(value: 0, timescale: 0),
                                                                      presentationTimeStamp: CMTimeMake(value: 0, timescale: 0),
                                                                      decodeTimeStamp: CMTimeMake(value: 0, timescale: 0)),
                                        count: count)
        CMSampleBufferGetSampleTimingInfoArray(sampleBuffer,
                                               entryCount: count,
                                               arrayToFill: &info,
                                               entriesNeededOut: &count)
        
        let scale = CMTimeScale(NSEC_PER_SEC)
        let presentationTime = CMTime(value: CMTimeValue(elapsed * Double(scale)), timescale: scale)
        
        for i in 0..<count {
            info[i].decodeTimeStamp = presentationTime
            info[i].presentationTimeStamp = presentationTime
        }
        
        var soundBuffer: CMSampleBuffer?
        CMSampleBufferCreateCopyWithNewTiming(allocator: kCFAllocatorDefault, sampleBuffer: sampleBuffer, sampleTimingEntryCount: count, sampleTimingArray: &info, sampleBufferOut: &soundBuffer)
        audioAssetWriterInput.append(soundBuffer!)
    }
}

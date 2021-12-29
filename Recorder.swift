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
    /// Pixedl Buffer Adoptor Holding Pixel Buffers and Feeding Them To Writer Input
    private var adoptor: AVAssetWriterInputPixelBufferAdaptor!
    /// Video Resolution To Record
    var width: Int
    var height: Int
    
    /// Audio Capture Session Using The Built-in Microphone
    private var audioCaptureSession: AVCaptureSession!
    
    /// Audio Output Used Writer
    private var audioOutput: AVCaptureAudioDataOutput!
    /// Audio Track Input of Recording
    private var audioAssetWriterInput: AVAssetWriterInput!
    /// Frame Count of AR Session Frames since AR Session started
    var frameCount: Int = 0
    var pixelBuffer: CVPixelBuffer?
    var pixelBytesPerRow: Int = 0
    var startedAt: Date?
    var elapsed: TimeInterval? {
        if let started = startedAt {
            return Date().timeIntervalSince(started)
        }
        return nil
    }
    let queue = DispatchQueue.init(label: "recordingQueue")
    weak var delegate: RecorderDelegate?
    var isReady: Bool = false
    // MARK: - Initialization
    init?(width: Int, height: Int) {
        self.width = width / 2
        self.height = height / 2
        
        super.init()
        
        outputURL = makeOutputURL(fileName: "myMovie.mov")
        
        do {
            try setupPixelBuffer()
        } catch {
            return nil
        }
        setupWriter()
    }
    
    // MARK: - Methods
    func update(renderedTexture: MTLTexture) {
        guard writer.status.rawValue != 0, isReady else { return }
        if startedAt == nil {
            startedAt = Date()
        }
        
        CVPixelBufferLockBaseAddress(pixelBuffer!, [])
        let bytes = CVPixelBufferGetBaseAddress(pixelBuffer!)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer!)
        let region = MTLRegionMake2D(0, 0, renderedTexture.width / 2, renderedTexture.height / 2)
        renderedTexture.getBytes( bytes!, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 1)
        
        CVPixelBufferUnlockBaseAddress( pixelBuffer!, [])
        
        let elapsed = Date().timeIntervalSince(startedAt!)
        let scale = CMTimeScale(NSEC_PER_SEC)
        let presentationTime = CMTime(value: CMTimeValue(elapsed * Double(scale)), timescale: scale)
        adoptor.append(pixelBuffer!, withPresentationTime: presentationTime)
    }
    
    private func setupPixelBuffer() throws {
        let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, nil, &self.pixelBuffer)
        guard status == kCVReturnSuccess else {
            throw RecorderError.pixelBufferError(description: "failed to initialize pixel buffer.", status: status)
        }
        pixelBytesPerRow = CVPixelBufferGetBytesPerRow(self.pixelBuffer!)
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
                                             AVVideoWidthKey: width,
                                             AVVideoHeightKey: height]
        writerInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: outputSettings)

        let bufferAttribs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height
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
    func startRecording() {
        queue.async { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.startAudioCapture()
            strongSelf.writer.startWriting()
            strongSelf.writer.startSession(atSourceTime: .zero)
            strongSelf.isReady = true
            
        }
    }
    
    /// Stop Recording Video
    func stopRecording() {
        queue.async { [weak self] in
            guard let strongSelf = self else { return }
            
            strongSelf.isReady = false
            strongSelf.audioAssetWriterInput.markAsFinished()
            strongSelf.writerInput.markAsFinished()
            strongSelf.writer.finishWriting {
                UISaveVideoAtPathToSavedPhotosAlbum(strongSelf.outputURL!.path, self, #selector(strongSelf.videoSaveCompletion(video:didFinishSavingWithError:contextInfo:)), nil)
            }
        }
    }
    
    @objc
    func videoSaveCompletion(video: NSString, didFinishSavingWithError: NSError?, contextInfo: UnsafeRawPointer?) {
        self.outputURL = self.makeOutputURL(fileName: "myMovie.mov")
        self.setupWriter()
        startedAt = nil
        delegate?.recorderDidFinishSavingRecording(self)
    }
    
    private func startAudioCapture() {
        audioCaptureSession = AVCaptureSession()
        if let captureDevice = AVCaptureDevice.default(for: .audio) {
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
}

extension Recorder: AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard writer.status.rawValue != 0, isReady, startedAt != nil else { return }
        
        queue.async {
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
            
            let elapsed = Date().timeIntervalSince(self.startedAt!)
            let scale = CMTimeScale(NSEC_PER_SEC)
            let presentationTime = CMTime(value: CMTimeValue(elapsed * Double(scale)), timescale: scale)
            
            for i in 0..<count {
                info[i].decodeTimeStamp = presentationTime
                info[i].presentationTimeStamp = presentationTime
            }
            
            var soundBuffer: CMSampleBuffer?
            CMSampleBufferCreateCopyWithNewTiming(allocator: kCFAllocatorDefault, sampleBuffer: sampleBuffer, sampleTimingEntryCount: count, sampleTimingArray: &info, sampleBufferOut: &soundBuffer)
            self.audioAssetWriterInput.append(soundBuffer!)
        }
    }
}

protocol RecorderDelegate: AnyObject {
    func recorderDidFinishSavingRecording(_ recorder: Recorder)
}

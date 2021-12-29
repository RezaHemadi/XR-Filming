//
//  Renderer.swift
//  VirtualSet
//
//  Created by Reza on 9/21/21.
//

import Foundation
import ARKit
import AVFoundation
import MetalKit
import os.signpost

// The max number of command buffers in flight
let kMaxBuffersInFlight: Int = 3
let kDefaultVideoFileName: String = "MyMovie.mov"
let kMaxPaletteSize: Int = 100

// The 16 byte aligned size of our uniforms structure
let kAlignedSharedUniformsSize: Int = (MemoryLayout<SharedUniforms>.size & ~0xFF) + 0x100
let kAlignedInstanceUniformsSize: Int = (MemoryLayout<InstanceUniforms>.size & ~0xFF) + 0x100
let kAlignedPaletteSize: Int = (MemoryLayout<matrix_float4x4>.stride & ~0xFF) + 0x100

// Vertex Data for an image plane
let kImagePlaneVertexData: [Float] = [
    -1.0, -1.0, 0.0, 1.0,
    1.0, -1.0, 1.0, 1.0,
    -1.0, 1.0, 0.0, 0.0,
    1.0, 1.0, 1.0, 0.0,
]

/// - Tag: AR Renderer
class Renderer: NSObject {
    
    // MARK: - Properties
    let session: ARSession
    let device: MTLDevice
    let inFlightSemaphore = DispatchSemaphore(value: kMaxBuffersInFlight)
    var renderDestination: RenderDestinationProvider?
    
    // Keep track of time of each frame
    var lastFrameTimestamp: Double = 0
    var frameDeltaTime: Double = 0
    var frameNumber: Int = 0
    
    // Metal Objects
    var commandQueue: MTLCommandQueue!
    var imagePlaneVertexBuffer: MTLBuffer!
    var sharedUniformsBuffer: MTLBuffer!
    var geometryUniformsBuffer: MTLBuffer!
    var capturedImagePipelineState: MTLRenderPipelineState!
    var capturedImageDepthState: MTLDepthStencilState!
    var capturedImageTextureY: CVMetalTexture!
    var capturedImageTextureCbCr: CVMetalTexture!
    var geometryPipelineState: MTLRenderPipelineState!
    var geometryVertexDescriptor: MTLVertexDescriptor!
    var geometryDepthState: MTLDepthStencilState!
    var paletteBuffer: MTLBuffer!
    
    // Captured Image Texture Cache
    var capturedImageTextureCache: CVMetalTextureCache!
    
    // Used to determine _uniformBufferStride each frame.
    //   This is the current frame number modulo kMaxBuffersInFlight
    var uniformBufferIndex: Int = 0
    
    // Offset within _sharedUniformBuffer to set for the current frame
    var sharedUniformBufferOffset: Int = 0
    
    // Offset within _geometryUniformBuffer to set for the current frame
    var geometryUniformBufferOffset: Int = 0
    
    var paletteBufferOffset: Int = 0
    
    // Addresses to write shared uniforms to each frame
    var sharedUniformBufferAddress: UnsafeMutableRawPointer!
    
    // Addresses to write geometry uniforms to each frame
    var geometryUniformBufferAddress: UnsafeMutableRawPointer!
    
    var paletteBufferAdress: UnsafeMutableRawPointer!
    
    // The current view port size
    var viewportSize: CGSize = CGSize()
    
    // Flag for viewport size changes
    var viewportSizeDidChange: Bool = false
    
    var captureResolution: VideoResolution?
    unowned var recorder: Recorder?
    
    // Read Buffer to capture video
    var readTexture: MTLTexture?
    var renderTextureWidth: Int?
    var renderTextureHeight: Int?
    var readBufferBytesPerRow: Int?
    var readBufferBytesPerImage: Int?
    var isRecording: Bool = false {
        didSet {
            guard oldValue != isRecording else { return }
            
            if isRecording {
                startRecording()
            } else {
                stopRecording()
            }
        }
    }
    
    // Video Capture
    var writer: AVAssetWriter!
    var writerInput: AVAssetWriterInput!
    var outputURL: URL!
    private var adoptor: AVAssetWriterInputPixelBufferAdaptor!
    var pixelBuffer: CVPixelBuffer?
    var startedAt: Date?
    var captureQueue = DispatchQueue.global(qos: .userInteractive)
    
    // Models To Render
    var setModel: SDModel?
    var rotation: Float = 0.0
    var isRotating: Bool = false
    
    // People Occlusion
    var matteGenerator: ARMatteGenerator
    var scenePlaneVertexBuffer: MTLBuffer!
    var compositePipelineState: MTLRenderPipelineState!
    var compositeDepthState: MTLDepthStencilState!
    var alphaTexture: MTLTexture!
    var dilatedDepthTexture: MTLTexture!
    var sceneColorTexture: MTLTexture!
    var sceneDepthTexture: MTLTexture!
    
    // MARK: - Initialization
    init(renderDestination: RenderDestinationProvider, device: MTLDevice) {
        session = ARSession()
        self.renderDestination = renderDestination
        self.device = device
        
        matteGenerator = ARMatteGenerator(device: device, matteResolution: .full)
        
        super.init()
        
        loadMetal()
        //session.delegate = self
        configureARSession()
        
        // Initialize Recording Assets
        // Make output URL
        do {
            var cachesDirectory: URL = try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            cachesDirectory.appendPathComponent(kDefaultVideoFileName)
            if FileManager.default.fileExists(atPath: cachesDirectory.path) {
                try FileManager.default.removeItem(atPath: cachesDirectory.path)
            }
            outputURL = cachesDirectory
        } catch {
            fatalError("failed to make output url")
        }
    }
    
    // MARK: - Methods
    func startRecording() {
        startedAt = Date()
        
        captureQueue.async { [weak self] in
            if let strongSelf = self {
                strongSelf.writer.startWriting()
                strongSelf.writer.startSession(atSourceTime: .zero)
            }
        }
    }
    
    func stopRecording() {
        writerInput.markAsFinished()
        writer.finishWriting {
                    UISaveVideoAtPathToSavedPhotosAlbum(self.outputURL!.path, self, #selector(self.videoSaveCompletion(video:didFinishSavingWithError:contextInfo:)), nil)
        }
    }
    
    @objc
    func videoSaveCompletion(video: NSString, didFinishSavingWithError: NSError?, contextInfo: UnsafeRawPointer?) {
        
    }
    
    func loadMetal() {
        // Create and load our basic metal state objects
        
        // Set the default formats needed to render
        renderDestination!.depthStencilPixelFormat = .depth32Float
        renderDestination!.colorPixelFormat = .bgra8Unorm
        renderDestination!.sampleCount = 1
        
        // Create a vertex buffer with our image plane vertex data
        let imagePlaneVertexDataCount = kImagePlaneVertexData.count * MemoryLayout<Float>.size
        imagePlaneVertexBuffer = device.makeBuffer(bytes: kImagePlaneVertexData, length: imagePlaneVertexDataCount, options: [])
        imagePlaneVertexBuffer.label = "ImagePlaneVertexBuffer"
        
        scenePlaneVertexBuffer = device.makeBuffer(bytes: kImagePlaneVertexData, length: imagePlaneVertexDataCount, options: [])
        scenePlaneVertexBuffer.label = "ScenePlaneVertexBuffer"
        
        // Calculate our uniform buffer sizes. We allocate kMaxBuffersInFlight instances for uniform
        //   storage in a single buffer. This allows us to update uniforms in a ring (i.e. triple
        //   buffer the uniforms) so that the GPU reads from one slot in the ring wil the CPU writes
        //   to another. Anchor uniforms should be specified with a max instance count for instancing.
        //   Also uniform storage must be aligned (to 256 bytes) to meet the requirements to be an
        //   argument in the constant address space of our shading functions.
        let sharedUniformBufferSize = kAlignedSharedUniformsSize * kMaxBuffersInFlight
        let geometryUniformBufferSize = kAlignedInstanceUniformsSize * kMaxBuffersInFlight
        let paletteBufferSize = kAlignedPaletteSize * kMaxPaletteSize * kMaxBuffersInFlight
        
        // Create and allocate our uniform buffer objects. Indicate shared storage so that both the
        //   CPU can access the buffer
        sharedUniformsBuffer = device.makeBuffer(length: sharedUniformBufferSize, options: .storageModeShared)
        sharedUniformsBuffer.label = "SharedUniformBuffer"
        
        geometryUniformsBuffer = device.makeBuffer(length: geometryUniformBufferSize, options: .storageModeShared)
        geometryUniformsBuffer.label = "GeometryUniformBuffer"
        
        paletteBuffer = device.makeBuffer(length: paletteBufferSize, options: .storageModeShared)
        paletteBuffer.label = "PaletteBuffer"
        
        // Load all shader files with a metal file extension in the project
        let defaultLibrary = device.makeDefaultLibrary()!
        
        let capturedImageVertexFunction = defaultLibrary.makeFunction(name: "capturedImageVertexTransform")
        let capturedImageFragmentFunction = defaultLibrary.makeFunction(name: "capturedImageFragmentShader")
        
        // Create a vertex descriptor for our image plane vertex buffer
        let imagePlaneVertexDescriptor = MTLVertexDescriptor()
        
        // Positions
        imagePlaneVertexDescriptor.attributes[0].format = .float2
        imagePlaneVertexDescriptor.attributes[0].offset = 0
        imagePlaneVertexDescriptor.attributes[0].bufferIndex = Int(kBufferIndexMeshPositions.rawValue)
        
        // Texture Coordinates
        imagePlaneVertexDescriptor.attributes[1].format = .float2
        imagePlaneVertexDescriptor.attributes[1].offset = 8
        imagePlaneVertexDescriptor.attributes[1].bufferIndex = Int(kBufferIndexMeshPositions.rawValue)
        
        // Buffer layout
        imagePlaneVertexDescriptor.layouts[0].stride = 16
        imagePlaneVertexDescriptor.layouts[0].stepRate = 1
        imagePlaneVertexDescriptor.layouts[0].stepFunction = .perVertex
        
        // Create a pipeline state for rendering the captured image
        let capturedImagePipelineStateDescriptor = MTLRenderPipelineDescriptor()
        capturedImagePipelineStateDescriptor.label = "MyCapturedImagePipeline"
        capturedImagePipelineStateDescriptor.sampleCount = renderDestination!.sampleCount
        capturedImagePipelineStateDescriptor.vertexFunction = capturedImageVertexFunction
        capturedImagePipelineStateDescriptor.fragmentFunction = capturedImageFragmentFunction
        capturedImagePipelineStateDescriptor.vertexDescriptor = imagePlaneVertexDescriptor
        capturedImagePipelineStateDescriptor.colorAttachments[0].pixelFormat = renderDestination!.colorPixelFormat
        capturedImagePipelineStateDescriptor.depthAttachmentPixelFormat = renderDestination!.depthStencilPixelFormat
        //capturedImagePipelineStateDescriptor.stencilAttachmentPixelFormat = renderDestination!.depthStencilPixelFormat
        
        do {
            capturedImagePipelineState = try device.makeRenderPipelineState(descriptor: capturedImagePipelineStateDescriptor)
        } catch {
            os_log(.error, "error creating render pipeline state for captured image: %s", "\(error)")
        }
        
        let capturedImageDepthStateDescriptor = MTLDepthStencilDescriptor()
        capturedImageDepthStateDescriptor.depthCompareFunction = .always
        capturedImageDepthStateDescriptor.isDepthWriteEnabled = false
        capturedImageDepthState = device.makeDepthStencilState(descriptor: capturedImageDepthStateDescriptor)
        
        // Create captured image texture cache
        var textureCache: CVMetalTextureCache?
        CVMetalTextureCacheCreate(nil, nil, device, nil, &textureCache)
        capturedImageTextureCache = textureCache
        
        // Create pipeline state for rendering geometry
        let geometryVertexDescriptor = MTLVertexDescriptor()
        
        // Position
        geometryVertexDescriptor.attributes[Int(kVertexAttributePosition.rawValue)].format = .float3
        geometryVertexDescriptor.attributes[Int(kVertexAttributePosition.rawValue)].offset = 0
        geometryVertexDescriptor.attributes[Int(kVertexAttributePosition.rawValue)].bufferIndex = Int(kBufferIndexMeshPositions.rawValue)
        
        // Texture Coordinates
        geometryVertexDescriptor.attributes[Int(kVertexAttributeTexcoord.rawValue)].format = .float2
        geometryVertexDescriptor.attributes[Int(kVertexAttributeTexcoord.rawValue)].offset = 3 * MemoryLayout<Float>.size
        geometryVertexDescriptor.attributes[Int(kVertexAttributeTexcoord.rawValue)].bufferIndex = Int(kBufferIndexMeshPositions.rawValue)
        
        // Normals
        geometryVertexDescriptor.attributes[Int(kVertexAttributeNormal.rawValue)].format = .float3
        geometryVertexDescriptor.attributes[Int(kVertexAttributeNormal.rawValue)].offset = 5 * MemoryLayout<Float>.size
        geometryVertexDescriptor.attributes[Int(kVertexAttributeNormal.rawValue)].bufferIndex = Int(kBufferIndexMeshPositions.rawValue)
        
        // Tangents
        geometryVertexDescriptor.attributes[Int(kVertexAttributeTangent.rawValue)].format = .float3
        geometryVertexDescriptor.attributes[Int(kVertexAttributeTangent.rawValue)].offset = 8 * MemoryLayout<Float>.size
        geometryVertexDescriptor.attributes[Int(kVertexAttributeTangent.rawValue)].bufferIndex = Int(kBufferIndexMeshPositions.rawValue)
        
        // BiTangents
        geometryVertexDescriptor.attributes[Int(kVertexAttributeBiTangent.rawValue)].format = .float3
        geometryVertexDescriptor.attributes[Int(kVertexAttributeBiTangent.rawValue)].offset = 11 * MemoryLayout<Float>.size
        geometryVertexDescriptor.attributes[Int(kVertexAttributeBiTangent.rawValue)].bufferIndex = Int(kBufferIndexMeshPositions.rawValue)
        
        // Ambient Occlusion Factor
        geometryVertexDescriptor.attributes[Int(kVertexAttributeAO.rawValue)].format = .float
        geometryVertexDescriptor.attributes[Int(kVertexAttributeAO.rawValue)].offset = 14 * MemoryLayout<Float>.size
        geometryVertexDescriptor.attributes[Int(kVertexAttributeAO.rawValue)].bufferIndex = Int(kBufferIndexMeshPositions.rawValue)
        
        // Joint Indices
        geometryVertexDescriptor.attributes[Int(kVertexAttributeJointIndices.rawValue)].format = .ushort4
        geometryVertexDescriptor.attributes[Int(kVertexAttributeJointIndices.rawValue)].offset = 15 * MemoryLayout<Float>.size
        geometryVertexDescriptor.attributes[Int(kVertexAttributeJointIndices.rawValue)].bufferIndex = Int(kBufferIndexMeshPositions.rawValue)
        
        // Joint Weights
        geometryVertexDescriptor.attributes[Int(kVertexAttributeJointWeights.rawValue)].format = .float4
        geometryVertexDescriptor.attributes[Int(kVertexAttributeJointWeights.rawValue)].offset = (15 * MemoryLayout<Float>.size) + MemoryLayout<simd_ushort4>.size
        geometryVertexDescriptor.attributes[Int(kVertexAttributeJointWeights.rawValue)].bufferIndex = Int(kBufferIndexMeshPositions.rawValue)
        
        // Buffer Layout
        geometryVertexDescriptor.layouts[0].stride = (19 * MemoryLayout<Float>.size) + (MemoryLayout<simd_ushort4>.size)
        
        self.geometryVertexDescriptor = geometryVertexDescriptor
        
        let geometryVertexFunction = defaultLibrary.makeFunction(name: "geometryVertexShader")
        let geometryFragmentFunction = defaultLibrary.makeFunction(name: "geometryFragmentShader")
        
        let geometryPipelineDescriptor = MTLRenderPipelineDescriptor()
        geometryPipelineDescriptor.label = "MyGeometryPipeline"
        geometryPipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        geometryPipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        geometryPipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        geometryPipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        geometryPipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        geometryPipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
        geometryPipelineDescriptor.isAlphaToOneEnabled = false
        geometryPipelineDescriptor.sampleCount = renderDestination!.sampleCount
        geometryPipelineDescriptor.vertexFunction = geometryVertexFunction
        geometryPipelineDescriptor.fragmentFunction = geometryFragmentFunction
        geometryPipelineDescriptor.vertexDescriptor = geometryVertexDescriptor
        geometryPipelineDescriptor.colorAttachments[0].pixelFormat = renderDestination!.colorPixelFormat
        geometryPipelineDescriptor.depthAttachmentPixelFormat = renderDestination!.depthStencilPixelFormat
        
        do {
            geometryPipelineState = try device.makeRenderPipelineState(descriptor: geometryPipelineDescriptor)
        } catch {
            os_log(.error, "error creating pipeline state for geometry: %s", "\(error)")
        }
        
        let geometryDepthStateDescriptor = MTLDepthStencilDescriptor()
        geometryDepthStateDescriptor.depthCompareFunction = .less
        geometryDepthStateDescriptor.isDepthWriteEnabled = true
        geometryDepthState = device.makeDepthStencilState(descriptor: geometryDepthStateDescriptor)
        
        // Create command queue
        commandQueue = device.makeCommandQueue()
    }
    
    func updateMatteTexture(commandBuffer: MTLCommandBuffer) {
        guard let currentFrame = session.currentFrame else {
            return
        }
        
        alphaTexture = matteGenerator.generateMatte(from: currentFrame, commandBuffer: commandBuffer)
        
        dilatedDepthTexture = matteGenerator.generateDilatedDepth(from: currentFrame, commandBuffer: commandBuffer)
    }
    func updatePalette() {
        guard let model = setModel else { return }
        
    }
    func configureARSession() {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        configuration.frameSemantics = .personSegmentationWithDepth
        session.run(configuration)
    }
    
    // MARK: - MTKView
    func drawRectResized(size: CGSize) {
        viewportSize = size
        viewportSizeDidChange = true
    }
    
    func update() {
        // Wait to ensure only kMaxBuffersInFlight are getting processes by any stage in the Metal
        //  pipeline (App, Metal, Drivers, GPU, etc)
        let _ = inFlightSemaphore.wait(timeout: DispatchTime.distantFuture)
        
        // Create a new command buffer for each renderpass to the current drawable
        if let commandBuffer = commandQueue.makeCommandBuffer() {
            commandBuffer.label = "MyCommand"
            
            // Add completion handler which signal _inFlightSemaphore when Metal and the GPU has fully
            //  finished processing we're encoding this frame. This indicates when the dynamic buffers,
            //  that we're writing to this frame, will no longer be needed by Metal and the GPU.
            // Retain our CVMetalTextures for the duration of the rendering cycle. The MTLTextures
            //  from the CVMetalTextures are not valid unless their parent CVMetalTextures are
            //  retained. Since we may release our CVMetalTexture ivars during the rendering cycle
            //  we must retain them seperately here.
            var textures = [capturedImageTextureY, capturedImageTextureCbCr]
            commandBuffer.addCompletedHandler { [weak self] commandBuffer in
                if let strongSelf = self {
                    if strongSelf.isRecording {
                        strongSelf.recordFrame()
                    }
                    strongSelf.inFlightSemaphore.signal()
                }
                textures.removeAll()
            }
            
            updateMatteTexture(commandBuffer: commandBuffer)
            updateBufferStates()
            updateGameStates()
            updatePalette()
            
            frameNumber = (frameNumber + 1) % 300
            
            guard sceneColorTexture != nil, sceneDepthTexture != nil else {
                commandBuffer.commit()
                return
                
            }
            
            if let renderPassDescriptor = renderDestination?.currentRenderPassDescriptor, let currentDrawable = renderDestination?.currentDrawable {
                
                // Setup offscreen render pass for later compositing
                guard let sceneRenderDescriptor = renderPassDescriptor.copy() as? MTLRenderPassDescriptor else {
                    fatalError("Unable to create a render pass descriptor.")
                }
                
                sceneRenderDescriptor.colorAttachments[0].texture = sceneColorTexture
                sceneRenderDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)
                sceneRenderDescriptor.colorAttachments[0].loadAction = .clear
                sceneRenderDescriptor.colorAttachments[0].storeAction = .store

                sceneRenderDescriptor.depthAttachment.texture = sceneDepthTexture
                sceneRenderDescriptor.depthAttachment.clearDepth = 1.0
                sceneRenderDescriptor.depthAttachment.loadAction = .clear
                sceneRenderDescriptor.depthAttachment.storeAction = .store
                
                if let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: sceneRenderDescriptor) {
                    renderEncoder.label = "MyRenderEncoder"
                    
                    drawCapturedImage(renderEncoder: renderEncoder)
                    renderEncoder.setVertexBuffer(paletteBuffer, offset: paletteBufferOffset, index: Int(kBufferIndexPalette.rawValue))
                    drawGeometry(renderEncoder: renderEncoder)
                    
                    // We're done encoding commands
                    renderEncoder.endEncoding()
                }
                
                // Perform final composite pass
                // Here we take the targets we just rendered camera and scene into and decide whether
                // to hide or show virtual content.
                if let compositeRenderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {

                    compositeRenderEncoder.label = "MyCompositeRenderEncoder"

                    // Composite images to final render targets
                    compositeImagesWithEncoder(renderEncoder: compositeRenderEncoder)

                    // We're done encoding commands
                    compositeRenderEncoder.endEncoding()
                }
                
                // If Recording session copy texture data
                if isRecording, readTexture != nil {
                    readTexture(commandBuffer: commandBuffer)
                }
                
                // Schedule a present once the framebuffer is complete using the current drawable
                commandBuffer.present(currentDrawable)
            }
            
            // Finalize rendering here & push the command buffer to the GPU
            commandBuffer.commit()
        }
    }
    
    func readTexture(commandBuffer: MTLCommandBuffer) {
        let blitEncoder = commandBuffer.makeBlitCommandEncoder()!
        blitEncoder.label = "MyBlitEncoder"
        
        blitEncoder.copy(from: renderDestination!.currentDrawable!.texture, to: readTexture!)
        
        blitEncoder.endEncoding()
    }
    
    func recordFrame() {
        guard writer.status.rawValue != 0 else { return }
        CVPixelBufferLockBaseAddress(pixelBuffer!, [])
        
        let bytes = CVPixelBufferGetBaseAddress(pixelBuffer!)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer!)
        let region = MTLRegionMake2D(0, 0, readTexture!.width, readTexture!.height)
        readTexture!.getBytes( bytes!, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
        
        CVPixelBufferUnlockBaseAddress( pixelBuffer!, [])
        
        let elapsed = Date().timeIntervalSince(startedAt!)
        let scale = CMTimeScale(NSEC_PER_SEC)
        let presentationTime = CMTime(value: CMTimeValue(elapsed * Double(scale)), timescale: scale)
        adoptor.append(pixelBuffer!, withPresentationTime: presentationTime)
    }
    
    func drawCapturedImage(renderEncoder: MTLRenderCommandEncoder) {
        guard let textureY = capturedImageTextureY, let textureCbCr = capturedImageTextureCbCr else {
            return
        }
        
        // Push a debug group allowing us to identify render commands in the GPU Frame Capture tool
        renderEncoder.pushDebugGroup("DrawCapturedImage")
        
        // Set render command encoder state
        renderEncoder.setCullMode(.none)
        renderEncoder.setRenderPipelineState(capturedImagePipelineState)
        renderEncoder.setDepthStencilState(capturedImageDepthState)
        
        // Set mesh's vertex buffers
        renderEncoder.setVertexBuffer(imagePlaneVertexBuffer, offset: 0, index: Int(kBufferIndexMeshPositions.rawValue))
        
        // Set any textures read/sampled from our render pipeline
        renderEncoder.setFragmentTexture(CVMetalTextureGetTexture(textureY), index: Int(kTextureIndexY.rawValue))
        renderEncoder.setFragmentTexture(CVMetalTextureGetTexture(textureCbCr), index: Int(kTextureIndexCbCr.rawValue))
        
        // Draw each submesh of our mesh
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        
        renderEncoder.popDebugGroup()
    }
    
    func drawGeometry(renderEncoder: MTLRenderCommandEncoder) {
        // Check If any geometry is available
        guard let setModel = self.setModel else {
            return
        }
        
        // Push a debug group allowing us to identify render commands in the GPU Frame Capture tool
        renderEncoder.pushDebugGroup("DrawGeometry")
        
        // Set render command encoder state
        renderEncoder.setCullMode(.back)
        renderEncoder.setFrontFacing(.counterClockwise)
        renderEncoder.setRenderPipelineState(geometryPipelineState)
        renderEncoder.setDepthStencilState(geometryDepthState)
        
        // Set any buffers fed into our render pipeline
        renderEncoder.setVertexBuffer(geometryUniformsBuffer, offset: geometryUniformBufferOffset, index: Int(kBufferIndexInstanceUniforms.rawValue))
        renderEncoder.setVertexBuffer(sharedUniformsBuffer, offset: sharedUniformBufferOffset, index: Int(kBufferIndexSharedUniforms.rawValue))
        renderEncoder.setFragmentBuffer(sharedUniformsBuffer, offset: sharedUniformBufferOffset, index: Int(kBufferIndexSharedUniforms.rawValue))
        renderEncoder.setFragmentBuffer(geometryUniformsBuffer, offset: geometryUniformBufferOffset, index: Int(kBufferIndexInstanceUniforms.rawValue))
        
        // Draw each Model
        setModel.render(renderEncoder: renderEncoder)
        
        renderEncoder.popDebugGroup()
    }
    
    func compositeImagesWithEncoder(renderEncoder: MTLRenderCommandEncoder) {
        guard let textureY = capturedImageTextureY, let textureCbCr = capturedImageTextureCbCr else {
            return
        }

        // Push a debug group allowing us to identify render commands in the GPU Frame Capture tool
        renderEncoder.pushDebugGroup("CompositePass")

        // Set render command encoder state
        renderEncoder.setCullMode(.none)
        renderEncoder.setRenderPipelineState(compositePipelineState)
        renderEncoder.setDepthStencilState(compositeDepthState)

        // Setup plane vertex buffers
        renderEncoder.setVertexBuffer(imagePlaneVertexBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(scenePlaneVertexBuffer, offset: 0, index: 1)

        // Setup textures for the composite fragment shader
        renderEncoder.setFragmentBuffer(sharedUniformsBuffer, offset: sharedUniformBufferOffset, index: Int(kBufferIndexSharedUniforms.rawValue))
        renderEncoder.setFragmentTexture(CVMetalTextureGetTexture(textureY), index: 0)
        renderEncoder.setFragmentTexture(CVMetalTextureGetTexture(textureCbCr), index: 1)
        renderEncoder.setFragmentTexture(sceneColorTexture, index: 2)
        renderEncoder.setFragmentTexture(sceneDepthTexture, index: 3)
        renderEncoder.setFragmentTexture(alphaTexture, index: 4)
        renderEncoder.setFragmentTexture(dilatedDepthTexture, index: 5)

        // Draw final quad to display
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        renderEncoder.popDebugGroup()
    }
    
    func updateBufferStates() {
        // Update the location(s) to which we'll write to in our dynamically changing Metal buffers for
        //   the current frame (i.e. update our slot in the ring buffer used for the current frame)
        
        uniformBufferIndex = (uniformBufferIndex + 1) % kMaxBuffersInFlight
        
        sharedUniformBufferOffset = kAlignedSharedUniformsSize * uniformBufferIndex
        geometryUniformBufferOffset = kAlignedInstanceUniformsSize * uniformBufferIndex
        paletteBufferOffset = kAlignedPaletteSize * kMaxPaletteSize * uniformBufferIndex
        
        
        sharedUniformBufferAddress = sharedUniformsBuffer.contents().advanced(by: sharedUniformBufferOffset)
        geometryUniformBufferAddress = geometryUniformsBuffer.contents().advanced(by: geometryUniformBufferOffset)
        paletteBufferAdress = paletteBuffer.contents().advanced(by: paletteBufferOffset)
    }
    
    func updateSharedUniforms(frame: ARFrame) {
        // Update the shared uniforms of the frame
        
        let uniforms = sharedUniformBufferAddress.assumingMemoryBound(to: SharedUniforms.self)
        
        uniforms.pointee.viewMatrix = frame.camera.viewMatrix(for: .landscapeRight)
        uniforms.pointee.projectionMatrix = frame.camera.projectionMatrix(for: .landscapeRight, viewportSize: viewportSize, zNear: 0.001, zFar: 1000)
        uniforms.pointee.cameraTransform = frame.camera.transform
        
        // Set up lighting for the scene using ambient intensity if provided
        var ambientIntensity: Float = 1.0
        
        if let lightEstimate = frame.lightEstimate {
            ambientIntensity = Float(lightEstimate.ambientIntensity) / 1000.0
        }
        
        let ambientLightColor: vector_float3 = vector3(0.8, 0.8, 0.8)
        uniforms.pointee.ambientLightColor = ambientLightColor * ambientIntensity
        
        var directionalLightDirection: vector_float3 = vector3(-1.0, 1.0, 1.0)
        directionalLightDirection = simd_normalize(directionalLightDirection)
        uniforms.pointee.directionalLightDirection = directionalLightDirection
        
        let directionalLightColor: vector_float3 = vector3(0.6, 0.6, 0.6)
        uniforms.pointee.directionalLightColor = directionalLightColor * ambientIntensity
        
        uniforms.pointee.materialShininess = 10
        
        // Check whether or not to sample estimated depth texture
        uniforms.pointee.useDepth = (session.configuration?.frameSemantics == ARConfiguration.FrameSemantics.personSegmentationWithDepth) ? 1 : 0
    }
    
    func updateGeometry(frame: ARFrame) {
        // Update Geometry Uniforms Based on data on current frame
        
        // Get Sufraces detected by ARKit
        let planeAnchors = frame.anchors.compactMap({ $0 as? ARPlaneAnchor })

        
        if let planeAnchor = planeAnchors.filter({ $0.transform.columns.3.y.isLess(than: 0.0)} ).sorted(by: {$0.area > $1.area}).first {
            // Flip Z axis to convert geometry from right handed to left handed
            //var coordinateSpaceTransform = matrix_identity_float4x4
            //coordinateSpaceTransform.columns.2.z = -1
            
            if isRotating { rotation += 0.01 }
            let rotationMatrix = matrix4x4_rotation(yaw: rotation)
            var modelMatrix = simd_mul(planeAnchor.transform, rotationMatrix)
            
            let geometryUniforms = geometryUniformBufferAddress.assumingMemoryBound(to: InstanceUniforms.self)
            geometryUniforms.pointee.modelMatrix = modelMatrix
            
            setModel?.updateGameState(cameraTransform: frame.camera.transform, modelTransform: modelMatrix, deltaTime: frameDeltaTime)
        }
    }
    
    func updateAnimations() {
        guard setModel != nil else { return }
        
        // get palette matrix
        let frameTime = Double(frameNumber) / 60.0
        if let palette = setModel?.calculatePaletteMatrix(frameTime: frameTime) {
            for index in 0..<palette.count {
                paletteBufferAdress.assumingMemoryBound(to: matrix_float4x4.self)[index] = palette[index]
            }
        }
    }
    
    func updateGameStates() {
        // update any game state
        
        guard let currentFrame = session.currentFrame else { return }
        
        frameDeltaTime = currentFrame.timestamp - lastFrameTimestamp
        lastFrameTimestamp = currentFrame.timestamp
        
        updateSharedUniforms(frame: currentFrame)
        updateGeometry(frame: currentFrame)
        updateAnimations()
        
        updateCapturedImageTextures(frame: currentFrame)
        
        if viewportSizeDidChange {
            viewportSizeDidChange = false
            
            setupCompositionAssets()
            
            let width = CVPixelBufferGetWidth(currentFrame.capturedImage)
            let height = CVPixelBufferGetHeight(currentFrame.capturedImage)
            captureResolution = VideoResolution(width: width, height: height)
            
            // Update Read Buffer
            if let renderTexture = renderDestination?.currentDrawable?.texture {
                let bytesPerPixel = 4 // size of BGRA8Unorm pixel format
                let bytesPerRow = bytesPerPixel * renderTexture.width
                let bytesPerImage = bytesPerRow * renderTexture.height
                renderTextureWidth = renderTexture.width
                renderTextureHeight = renderTexture.height
                readBufferBytesPerRow = bytesPerRow
                readBufferBytesPerImage = bytesPerImage
                let descriptor = MTLTextureDescriptor()
                descriptor.pixelFormat = renderTexture.pixelFormat
                descriptor.width = renderTexture.width
                descriptor.height = renderTexture.height
                descriptor.storageMode = .shared
                readTexture = device.makeTexture(descriptor: descriptor)
                
                // Initialize Pixel Buffer
                let status = CVPixelBufferCreate(kCFAllocatorDefault, renderTexture.width, renderTexture.height, kCVPixelFormatType_32BGRA, nil, &self.pixelBuffer)
                if status == kCVReturnSuccess {
                    os_log(.info, "successfully created pixel buffer")
                } else {
                    fatalError("failed to create pixel buffer")
                }
                
                os_log(.info, "initialized read texture")
                
                // Setup Video Writer
                do {
                    writer = try AVAssetWriter(outputURL: outputURL, fileType: .mov)
                    let outputSettings: [String: Any] = [AVVideoCodecKey: AVVideoCodecType.h264,
                                                         AVVideoWidthKey: renderTexture.width,
                                                        AVVideoHeightKey: renderTexture.height]
                    writerInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: outputSettings)
                    
                } catch {
                    fatalError("failed to initialize writer")
                }
                
                let bufferAttribs: [String: Any] = [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                    kCVPixelBufferWidthKey as String: CVPixelBufferGetWidth(pixelBuffer!),
                    kCVPixelBufferHeightKey as String: CVPixelBufferGetHeight(pixelBuffer!)
                ]
                adoptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: writerInput, sourcePixelBufferAttributes: bufferAttribs)
                writer.add(writerInput)
                writerInput.expectsMediaDataInRealTime = true
            }
            
            updateImagePlane(frame: currentFrame)
        }
    }
    
    func updateImagePlane(frame: ARFrame) {
        // Update the texture coordinates of our image plane to aspect fill the viewport
        let displayToCameraTransform = frame.displayTransform(for: .landscapeRight, viewportSize: viewportSize).inverted()
        
        let vertexData = imagePlaneVertexBuffer.contents().assumingMemoryBound(to: Float.self)
        let compositeVertexData = scenePlaneVertexBuffer.contents().assumingMemoryBound(to: Float.self)
        for index in 0...3 {
            let textureCoordIndex = 4 * index + 2
            let textureCoord = CGPoint(x: CGFloat(kImagePlaneVertexData[textureCoordIndex]), y: CGFloat(kImagePlaneVertexData[textureCoordIndex + 1]))
            let transformedCoord = textureCoord.applying(displayToCameraTransform)
            vertexData[textureCoordIndex] = Float(transformedCoord.x)
            vertexData[textureCoordIndex + 1] = Float(transformedCoord.y)
            
            compositeVertexData[textureCoordIndex] = kImagePlaneVertexData[textureCoordIndex]
            compositeVertexData[textureCoordIndex + 1] = kImagePlaneVertexData[textureCoordIndex + 1]
        }
    }
    
    func updateCapturedImageTextures(frame: ARFrame) {
        // Create two textures ( Y and CbCr ) from the provided frame's captured image
        let pixelBuffer = frame.capturedImage
        
        if (CVPixelBufferGetPlaneCount(pixelBuffer) < 2) {
            return
        }
        
        capturedImageTextureY = createTexture(fromPixelBuffer: pixelBuffer, pixelFormat: .r8Unorm, planeIndex: 0)
        capturedImageTextureCbCr = createTexture(fromPixelBuffer: pixelBuffer, pixelFormat: .rg8Unorm, planeIndex: 1)
    }
    
    func createTexture(fromPixelBuffer pixelBuffer: CVPixelBuffer, pixelFormat: MTLPixelFormat, planeIndex: Int) -> CVMetalTexture? {
        let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, planeIndex)
        let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, planeIndex)
        
        var texture: CVMetalTexture? = nil
        let status = CVMetalTextureCacheCreateTextureFromImage(nil, capturedImageTextureCache, pixelBuffer, nil, pixelFormat, width, height, planeIndex, &texture)
        
        if status != kCVReturnSuccess {
            texture = nil
        }
        
        return texture
    }
    
    func saveImageFromPixelBuffer() {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer!)
        let tempContext = CIContext()
        let image = tempContext.createCGImage(ciImage, from: CGRect(x: 0,
                                                                    y: 0,
                                                                    width: CVPixelBufferGetWidth(pixelBuffer!),
                                                                    height: CVPixelBufferGetHeight(pixelBuffer!)))!
        let uiImage = UIImage(cgImage: image)
        UIImageWriteToSavedPhotosAlbum(uiImage, nil, nil, nil)
    }
    
    func setupCompositionAssets() {
        // Create render targets for offscreen camera image and scene render
        let defaultLibrary = device.makeDefaultLibrary()!
        let width = renderDestination!.currentDrawable!.texture.width
        let height = renderDestination!.currentDrawable!.texture.height
        
        let colorDesc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: renderDestination!.colorPixelFormat,
                                                                 width: width,
                                                                 height: height, mipmapped: false)
        colorDesc.usage = MTLTextureUsage(rawValue: MTLTextureUsage.renderTarget.rawValue | MTLTextureUsage.shaderRead.rawValue)
        sceneColorTexture = device.makeTexture(descriptor: colorDesc)
        
        let depthDesc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: renderDestination!.depthStencilPixelFormat,
                                                                 width: width, height: height, mipmapped: false)
        depthDesc.usage = MTLTextureUsage(rawValue: MTLTextureUsage.renderTarget.rawValue | MTLTextureUsage.shaderRead.rawValue)
        sceneDepthTexture = device.makeTexture(descriptor: depthDesc)
        
        // Create composite pipeline
        let compositeImageVertexFunction = defaultLibrary.makeFunction(name: "compositeImageVertexTransform")!
        let compositeImageFragmentFunction = defaultLibrary.makeFunction(name: "compositeImageFragmentShader")!

        let compositePipelineStateDescriptor = MTLRenderPipelineDescriptor()
        compositePipelineStateDescriptor.label = "MyCompositePipeline"
        compositePipelineStateDescriptor.sampleCount = renderDestination!.sampleCount
        compositePipelineStateDescriptor.vertexFunction = compositeImageVertexFunction
        compositePipelineStateDescriptor.fragmentFunction = compositeImageFragmentFunction
        compositePipelineStateDescriptor.colorAttachments[0].pixelFormat = renderDestination!.colorPixelFormat
        compositePipelineStateDescriptor.depthAttachmentPixelFormat = renderDestination!.depthStencilPixelFormat

        do {
            try compositePipelineState = device.makeRenderPipelineState(descriptor: compositePipelineStateDescriptor)
        } catch let error {
            print("Failed to create composite pipeline state, error \(error)")
        }

        let compositeDepthStateDescriptor = MTLDepthStencilDescriptor()
        compositeDepthStateDescriptor.depthCompareFunction = .always
        compositeDepthStateDescriptor.isDepthWriteEnabled = false
        compositeDepthState = device.makeDepthStencilState(descriptor: compositeDepthStateDescriptor)
    }
}

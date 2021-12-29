//
//  ARViewRenderer.swift
//  VirtualSet
//
//  Created by Reza on 10/3/21.
//

import Foundation
import RealityKit
import Combine
import Metal
import ARKit
import os.signpost
import MetalPerformanceShaders
import SwiftUI

let kStageMeshCollisionGroup: UInt32 = 10
let kPhotoPlaneCollisionGroup: UInt32 = 11
let kCollisionMaskGroup: UInt32 = 12
let kPictureFrameName: String = "PictureFrame"
/// name of the predefined node which determine the position of photo plane entity
let kPictureNodeName: String = "EmptyPictureFrame"
/// When there is no picture frame on stage and user adds a photo in the predefined position node
/// this is the name given to that plane with user added image texture.
let kPicturePlaneName: String = "PhotoPlane"

class ARViewRenderer: NSObject {
    // MARK: - Properties
    let arView: ARView
    var device: MTLDevice!
    
    private var isRecording: Bool = false {
        didSet {
            guard oldValue != isRecording else { return }
            
            isRecording ? startRecording() : stopRecording()
        }
    }
    
    private var recorder: Recorder?
    private var streams: [AnyCancellable] = []
    private var recordingTexture: MTLTexture!
    private var watchTexture: MTLTexture!
    private var watchRGBATexture: MTLTexture!
    private var textureWidth: Int?
    private var textureHeight: Int? {
        didSet {
            guard textureHeight != nil, oldValue != textureHeight else { return }
            
            watchTexture = nil
            
            os_log(.info, "initializing watch texture")
            
            // Inform delegate of watch texture update
            delegate?.rendererDidUpdateWatchTexture(self, width: textureWidth! / 32, height: textureHeight! / 32)
            
            initializeWatchTexture(device: device, width: textureWidth!, height: textureHeight!) { texture in
                self.watchTexture = texture
            }
            
        }
    }
    private var stage: Entity?
    private var photoPlane: ModelEntity?
    private var animControllers: [AnimationPlaybackController] = []
    private var animations: [AnimationResource] = []
    weak var delegate: ARViewRendererDelegate?
    weak var dataSource: ARViewRendererDataSource?
    var gestureEntity: Entity? {
        didSet {
            guard gestureEntity != nil else { return }
            
            os_log(.info, "gesture entity: %s", "\(gestureEntity!.name)")
        }
    }
    var floorAnchor: AnchorEntity?
    var directionalLight: DirectionalLight?
    var directionalLightAnchor: AnchorEntity?
    
    /// Stage Position in Drag Gesture Start
    /// in world space
    private var modelOriginalPosition: SIMD3<Float>?
    
    // reference to stage picture frame model
    var pictureFrame: ModelEntity?
    
    var watchFrameCounter: Int = 0
    var shouldSendWatchUpdates: Bool = false
    
    var usedCustomPhoto: Bool = false
    
    var environment: ModelEntity?
    
    var floorDetected: Bool = false {
        didSet {
            guard oldValue != floorDetected else { return }
            
            delegate?.rendererTrackingStateDidChange(self, isTracking: floorDetected && isTrackingNormal)
        }
    }
    var isTrackingNormal: Bool = false {
        didSet {
            guard oldValue != isTrackingNormal else { return }
            
            delegate?.rendererTrackingStateDidChange(self, isTracking: floorDetected && isTrackingNormal)
        }
    }
    
    // MARK: Initialization
    init(_ arView: ARView, isRecording: Published<Bool>.Publisher) {
        self.arView = arView
        super.init()
        arView.session.delegate = self
        
        arView.renderCallbacks.prepareWithDevice = { [weak self] device in
            self?.prepareWithDevice(device)
        }
        
        arView.renderCallbacks.postProcess = { [weak self] context in
            self?.postProcess(context)
        }
        
        let stream = isRecording.sink { value in
            self.isRecording = value
        }
        stream.store(in: &streams)
        
        arView.renderOptions = [.disableGroundingShadows,
                                .disableHDR,
                                .disableAREnvironmentLighting]
    }
    
    // MARK: - Methods
    func anchorSetAtPoint(_ point: CGPoint) {
        
    }
    
    func makeTexture(matching texture: MTLTexture) -> MTLTexture? {
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.width = texture.width
        textureDescriptor.height = texture.height
        textureDescriptor.pixelFormat = texture.pixelFormat
        textureDescriptor.textureType = .type2D
        textureDescriptor.mipmapLevelCount = 2
        textureDescriptor.usage = [.shaderWrite, .shaderRead]
        
        return device.makeTexture(descriptor: textureDescriptor)
    }
    
    func translateSet(value: DragGesture.Value) {
        #if !targetEnvironment(simulator)
        guard gestureEntity != nil else { return }
        
        if modelOriginalPosition == nil {
            modelOriginalPosition = gestureEntity!.transformMatrix(relativeTo: nil).translation
        }
        
        let point = value.location
        
        // If entity is picture frame hit test against stage surfaces
        if gestureEntity!.name == "Photo", let ray = arView.ray(through: point) {
            let results = arView.scene.raycast(origin: ray.origin, direction: ray.direction)
            if let result = results.first(where: { ($0.entity.components[CollisionComponent.self] as! CollisionComponent).filter.group.rawValue == kStageMeshCollisionGroup }) {
                
                var transform = gestureEntity!.transformMatrix(relativeTo: nil)
                transform.columns.3.x = result.position.x
                transform.columns.3.y = result.position.y
                transform.columns.3.z = result.position.z + 0.02
                
                gestureEntity!.move(to: transform, relativeTo: nil, duration: 0.3, timingFunction: .easeInOut)
                return
            }
        }
        
        
        /*
        let raycastResults = arView.raycast(from: point, allowing: .existingPlaneGeometry, alignment: .horizontal)
        
        if let result = raycastResults.first {
            let targetMatrix = result.worldTransform
            var modelWorldTransform = gestureEntity!.transformMatrix(relativeTo: nil)
            modelWorldTransform.columns.3.x = targetMatrix.columns.3.x
            modelWorldTransform.columns.3.y = targetMatrix.columns.3.y
            modelWorldTransform.columns.3.z = targetMatrix.columns.3.z
            gestureEntity!.move(to: modelWorldTransform, relativeTo: nil, duration: 0.3, timingFunction: .easeInOut)
            
            return
        } */
        
        /// Translating user input to camera space translation
        let delta: SIMD3<Float> = [Float(value.translation.width), 0, Float(value.translation.height)] / ((150.0) / kDragGestureSensitivity)
        
        /// Transform delta to world space
        let worldSpaceDelta = simd_mul(arView.cameraTransform.matrix, [delta.x, delta.y, delta.z, 0.0])
        
        /// Project transform delta to x and z planes
        let projectedOnXZPlaneWorldSpaceDelta: SIMD3<Float> = [worldSpaceDelta.x, 0.0, worldSpaceDelta.z]
        
        /// Model position after applying delta
        let position = modelOriginalPosition! + projectedOnXZPlaneWorldSpaceDelta
        
        let originalModelTransform = gestureEntity!.transformMatrix(relativeTo: nil)
        
        let col0 = originalModelTransform.columns.0
        let col1 = originalModelTransform.columns.1
        let col2 = originalModelTransform.columns.2
        let col3: SIMD4<Float> = [position.x, position.y, position.z, originalModelTransform.columns.3.w]
        
        let transformedModelMatrix = matrix_float4x4([col0, col1, col2, col3])
        
        gestureEntity!.move(to: transformedModelMatrix, relativeTo: nil, duration: 0.3, timingFunction: .easeInOut)
        
        #endif
    }
    
    func commitSetTranslation(value: DragGesture.Value) {
        modelOriginalPosition = nil
    }
    
    func scaleSet(magnitude: CGFloat) {
        guard gestureEntity != nil else { return }
        
        /// Scale the model with anchor point at it's center bottom
        let modelOriginalTransform = gestureEntity!.transformMatrix(relativeTo: gestureEntity!)
        
        /// Find the bounding box of the model in it's own space
        let boundingBox = gestureEntity!.visualBounds(recursive: true, relativeTo: stage!, excludeInactive: false)
        
        /// Project bounding box on XZ plane
        let anchorPoint: SIMD3<Float> = [boundingBox.center.x, 0, boundingBox.center.z]
        
        /// Translate the model to anchor point
        let translationMatrix = matrix_float4x4_translation(translationX: -anchorPoint.x, translationY: -anchorPoint.y, translationZ: -anchorPoint.z)
        let translatedModel = simd_mul(translationMatrix, modelOriginalTransform)
        
        /// Scale the model
        let scaleFactor = Float(magnitude)
        let scaleMatrix = matrix4x4_scale(scaleX: scaleFactor, scaleY: scaleFactor, scaleZ: scaleFactor)
        let scaledModel = simd_mul(scaleMatrix, translatedModel)
        
        /// Translate the model back to it's original position
        let originalTransltionMatrix = matrix_float4x4_translation(translationX: anchorPoint.x, translationY: -anchorPoint.y, translationZ: anchorPoint.z)
        let newTransform = simd_mul(originalTransltionMatrix, scaledModel)
        
        /// Move the model to new transform relative to it's own space
        gestureEntity!.move(to: newTransform, relativeTo: gestureEntity!, duration: 0.3, timingFunction: .easeInOut)
    }
    
    func commitScaleSet(endMagnitude: CGFloat) {
        
    }
    
    func rotateSet(angle: RotationGesture.Value) {
        guard stage != nil else { return }
        
        let modelOriginalTransform = stage!.transformMatrix(relativeTo: stage!)
        
        /// Find the bounding box of the model in it's own space
        let boundingBox = stage!.visualBounds(recursive: true, relativeTo: stage!, excludeInactive: false)
        
        /// Project bounding box on XZ plane
        let anchorPoint: SIMD3<Float> = [boundingBox.center.x, 0, boundingBox.center.z]
        
        /// Translate the model to anchor point
        let translationMatrix = matrix_float4x4_translation(translationX: -anchorPoint.x, translationY: -anchorPoint.y, translationZ: -anchorPoint.z)
        let translatedModel = simd_mul(translationMatrix, modelOriginalTransform)
        
        let rotationValue = Float(angle.radians) * kRotationGestureSensitivity
        let rotationTransform = Transform.init(pitch: 0, yaw: -rotationValue, roll: 0)
        
        let rotatedModel = simd_mul(rotationTransform.matrix, translatedModel)
        
        let originalTransltionMatrix = matrix_float4x4_translation(translationX: anchorPoint.x, translationY: -anchorPoint.y, translationZ: anchorPoint.z)
        
        let newTransform = simd_mul(originalTransltionMatrix, rotatedModel)
        
        stage!.move(to: newTransform, relativeTo: stage!, duration: 0.3, timingFunction: .easeInOut)
    }
    
    func commitRotateSet(angle: RotationGesture.Value) {
        
    }
    
    func scaleAndRotate(angle: RotationGesture.Value, magnitude: MagnificationGesture.Value) {
        /// Scale the model with anchor point at it's center bottom
        guard let entity = gestureEntity else { return }
        
        let modelOriginalTransform = entity.transformMatrix(relativeTo: entity)
        
        /// Find the bounding box of the model in it's own space
        let boundingBox = entity.visualBounds(recursive: true, relativeTo: entity, excludeInactive: false)
        
        /// Project bounding box on XZ plane
        let anchorPoint: SIMD3<Float> = [boundingBox.center.x, 0, boundingBox.center.z]
        
        /// Translate the model to anchor point
        let translationMatrix = matrix_float4x4_translation(translationX: -anchorPoint.x, translationY: -anchorPoint.y, translationZ: -anchorPoint.z)
        let translatedModel = simd_mul(translationMatrix, modelOriginalTransform)
        
        /// Scale the model
        let scaleFactor = powf(Float(magnitude), (kScaleGestureSensitivity / 2.0))
        let scaleMatrix = matrix4x4_scale(scaleX: scaleFactor, scaleY: scaleFactor, scaleZ: scaleFactor)
        let scaledModel = simd_mul(scaleMatrix, translatedModel)
        
        /// rotate
        let rotationValue = Float(angle.radians) * kRotationGestureSensitivity
        let rotationTransform = Transform.init(pitch: 0, yaw: -rotationValue, roll: 0)
        
        let rotatedModel = simd_mul(rotationTransform.matrix, scaledModel)
        
        let originalTransltionMatrix = matrix_float4x4_translation(translationX: anchorPoint.x, translationY: -anchorPoint.y, translationZ: anchorPoint.z)
        
        let newTransform = simd_mul(originalTransltionMatrix, rotatedModel)
        
        entity.move(to: newTransform, relativeTo: entity, duration: 0.3, timingFunction: .easeInOut)
    }
    
    func selectEntityAt(_ location: CGPoint) {
        let ray = arView.ray(through: location)!
        let results = arView.scene.raycast(origin: ray.origin, direction: ray.direction)
        for result in results {
            let collisition: CollisionComponent = result.entity.components[CollisionComponent.self] as! CollisionComponent
            if collisition.filter.group.rawValue == kPhotoPlaneCollisionGroup {
                self.gestureEntity = result.entity
                return
            }
        }
        
        gestureEntity = stage
    }
    
    func addStage(_ stage: Entity, environment: ModelEntity? = nil) {
        /*
        let sphereMesh = MeshResource.generateSphere(radius: 600.0)
        var material = PhysicallyBasedMaterial()
        let semantic: TextureResource.Semantic = .color
        let textureResource = try! TextureResource.load(named: "snowy_park_01_4k.exr")
        let texture = MaterialParameters.Texture.init(textureResource)
        //material.color = UnlitMaterial.BaseColor(tint: .white, texture: texture)
        material.baseColor = PhysicallyBasedMaterial.BaseColor(tint: UIColor.white, texture: texture)
        material.emissiveColor = PhysicallyBasedMaterial.EmissiveColor(color: .init(white: 0.2, alpha: 1.0), texture: texture)
        material.emissiveIntensity = 1.0
        material.faceCulling = .none
        let sphere = ModelEntity(mesh: sphereMesh, materials: [material]) */
        
        stage.generateCollisionShapes(recursive: true)
        processStage(stage)
        self.stage = stage
        self.gestureEntity = stage
        #if !targetEnvironment(simulator)
        let floorAnchor = AnchorEntity(plane: .horizontal, classification: .floor, minimumBounds: [1.5, 1.5])
        self.floorAnchor = floorAnchor
        arView.scene.addAnchor(floorAnchor)
        floorAnchor.addChild(stage)
        if environment != nil {
            floorAnchor.addChild(environment!)
            self.environment = environment
        }
        #endif
        
        let lightNode = Entity()
        let light = DirectionalLightComponent(color: .white, intensity: 2345.0)
        lightNode.components[DirectionalLightComponent.self] = light
        let lightAnchor = AnchorEntity()
        lightAnchor.transform = arView.cameraTransform
        lightAnchor.addChild(lightNode)
        
        arView.scene.addAnchor(lightAnchor)
        self.directionalLightAnchor = lightAnchor
        
        // Get a reference to stage pictureframe
        if let pictureFrameEntity = stage.findEntity(named: kPictureFrameName) as? ModelEntity {
            self.pictureFrame = pictureFrameEntity
            var collisionComponent: CollisionComponent = self.pictureFrame!.components[CollisionComponent.self]!
            collisionComponent.filter = CollisionFilter.init(group: .init(rawValue: kPhotoPlaneCollisionGroup), mask: .init(rawValue: kCollisionMaskGroup))
            self.pictureFrame!.components[CollisionComponent.self] = collisionComponent
        }
    }
    
    func clearScene() {
        if stage != nil, floorAnchor != nil {
            arView.scene.removeAnchor(self.floorAnchor!)
            arView.scene.anchors.removeAll()
        }
        self.stage = nil
        self.photoPlane = nil
        self.pictureFrame = nil
        self.usedCustomPhoto = false
        self.environment = nil
    }
    
    private func processStage(_ stage: Entity) {
        func processEntity(_ entity: Entity) {
            if var collision: CollisionComponent = entity.components[CollisionComponent.self] {
                os_log(.info, "collision component for %s\n%s", "\(entity.name)", "\(collision)")
                
                collision.filter = CollisionFilter(group: .init(rawValue: kStageMeshCollisionGroup), mask: .init(rawValue: kCollisionMaskGroup))
                
                entity.components[CollisionComponent.self] = collision
            }
            
            for child in entity.children {
                processEntity(child)
            }
        }
        
        for child in stage.children {
            processEntity(child)
        }
    }
    
    func snapshot() {
        arView.snapshot(saveToHDR: false) { [self] image in
            if let yourImage = image {
                DispatchQueue.main.async {
                    UIImageWriteToSavedPhotosAlbum(yourImage, self, nil, nil)
                    delegate?.renderer(self, didSaveSnapshot: true)
                }
            }
        }
        
        saveSnapshotObject()
    }
    
    func addImagePlane(_ image: UIImage) {
        DispatchQueue.main.async { [self] in
            let aspectRatio = Float(image.size.width / image.size.height)
            let planeMesh = MeshResource.generatePlane(width: 0.35, height: 0.35 / aspectRatio)
            var material = PhysicallyBasedMaterial()
            let semantic: TextureResource.Semantic = .color
            let options = TextureResource.CreateOptions(semantic: semantic)
            let textureResource = try! TextureResource.generate(from: image.cgImage!, withName: "my plane", options: options)
            let texture = MaterialParameters.Texture.init(textureResource)
            material.baseColor = PhysicallyBasedMaterial.BaseColor(tint: UIColor.white, texture: texture)
            let planeEntity = ModelEntity(mesh: planeMesh, materials: [material])
            planeEntity.name = "Photo"
            planeEntity.generateCollisionShapes(recursive: true)
            var collision: CollisionComponent = planeEntity.components[CollisionComponent.self]!
            collision.filter = CollisionFilter.init(group: .init(rawValue: kPhotoPlaneCollisionGroup), mask: .init(rawValue: kCollisionMaskGroup))
            planeEntity.components[CollisionComponent.self] = collision
            let initialTransform = matrix_float4x4_translation(translationX: 0.0, translationY: 0.0, translationZ: 0.3)
            self.photoPlane = planeEntity
            stage!.addChild(planeEntity)
            planeEntity.move(to: initialTransform, relativeTo: stage!)
        }
        
    }
    
    func addImage(_ image: UIImage) {
        usedCustomPhoto = true
        
        if let pictureFrame = self.pictureFrame {
            DispatchQueue.main.async {
                var material = PhysicallyBasedMaterial()
                let semantic: TextureResource.Semantic = .color
                let options = TextureResource.CreateOptions(semantic: semantic)
                let textureResource = try! TextureResource.generate(from: image.cgImage!, withName: "my plane", options: options)
                let texture = MaterialParameters.Texture.init(textureResource)
                material.baseColor = PhysicallyBasedMaterial.BaseColor(tint: UIColor.white, texture: texture)
                pictureFrame.model!.materials = [material]
            }
        } else {
            if let pictureFrame = stage!.findEntity(named: kPictureNodeName) {
                DispatchQueue.main.async {
                    let aspectRatio = Float(image.size.width / image.size.height)
                    let planeMesh = MeshResource.generatePlane(width: 1.0, height: 1.0 / aspectRatio)
                    var material = PhysicallyBasedMaterial()
                    let semantic: TextureResource.Semantic = .color
                    let options = TextureResource.CreateOptions(semantic: semantic)
                    let textureResource = try! TextureResource.generate(from: image.cgImage!, withName: "my plane", options: options)
                    let texture = MaterialParameters.Texture.init(textureResource)
                    material.baseColor = PhysicallyBasedMaterial.BaseColor(tint: UIColor.white, texture: texture)
                    let planeEntity = ModelEntity(mesh: planeMesh, materials: [material])
                    planeEntity.name = kPicturePlaneName
                    planeEntity.generateCollisionShapes(recursive: true)
                    var collision: CollisionComponent = planeEntity.components[CollisionComponent.self]!
                    collision.filter = CollisionFilter.init(group: .init(rawValue: kPhotoPlaneCollisionGroup), mask: .init(rawValue: kCollisionMaskGroup))
                    planeEntity.components[CollisionComponent.self] = collision
                    let worldTransform = pictureFrame.convert(transform: Transform(), to: self.stage!)
                    
                    let pictureTransform = Transform(scale: [1.0, 1.0, 1.0], rotation: worldTransform.rotation, translation: worldTransform.translation)
                    self.photoPlane = planeEntity
                    self.stage!.addChild(planeEntity)
                    planeEntity.move(to: pictureTransform, relativeTo: self.stage!)
                }
            }
        }
    }
    
    func removeSelectedImageEntity() {
        if let selectedEntity = gestureEntity as? ModelEntity {
            if selectedEntity.name == kPictureFrameName {
                var material = PhysicallyBasedMaterial()
                let semantic: TextureResource.Semantic = .color
                let options = TextureResource.CreateOptions(semantic: semantic)
                let image = UIImage(named: "ReplaceMe")!.cgImage
                let textureResource = try! TextureResource.generate(from: image!, withName: "ReplaceMe", options: options)
                let texture = MaterialParameters.Texture.init(textureResource)
                material.baseColor = PhysicallyBasedMaterial.BaseColor(tint: UIColor.white, texture: texture)
                selectedEntity.model?.materials = [material]
            } else if selectedEntity.name == kPicturePlaneName {
                self.stage?.removeChild(selectedEntity)
            }
        }
    }
    
    // MARK: - Helper Methods
    private func startRecording() {
        guard let width = textureWidth, let height = textureHeight else { fatalError() }
        
        prepareRecorder(device: device, width: width, height: height) { recorder, texture in
            self.recordingTexture = texture
            self.recorder = recorder
            self.recorder!.delegate = self
            self.recorder!.startRecording()
        }
    }
    
    private func stopRecording() {
        textureWidth = nil
        textureHeight = nil
        recordingTexture = nil
        
        saveRecordingObject()
        
        recorder?.stopRecording()
    }
    
    private func saveRecordingObject() {
        let recordingObject = PFVideoRecordings()
        
        if let elapsed = recorder?.elapsed {
            recordingObject.Duration = NSNumber(value: elapsed)
        }
        
        let isLandscape = UIDevice.current.orientation.isLandscape
        recordingObject.IsLandscape = isLandscape
        
        let preview = dataSource!.currentStagePreview()
        recordingObject.StageName = preview.name
        
        recordingObject.UsedCustomPic = usedCustomPhoto
        
        var stageObject: PFVirtualStage?
        switch preview.source {
        case .bundle(let bundleSet):
            break
        case .server(let virtualStage):
            stageObject = virtualStage.object
            recordingObject.Stage = stageObject!
        }
        
        recordingObject.saveInBackground { success, error in
            if let error = error {
                self.delegate?.rendererDidEncounterNetwordError(self)
            }
        }
    }
    
    private func saveSnapshotObject() {
        let snapshotObject = PFSnapshot()
        
        let isLandscape = UIDevice.current.orientation.isLandscape
        snapshotObject.IsLandscape = isLandscape
        
        let preview = dataSource!.currentStagePreview()
        snapshotObject.StageName = preview.name
        
        snapshotObject.UsedCustomPic = usedCustomPhoto
        
        var stageObject: PFVirtualStage?
        switch preview.source {
        case .bundle(let bundleSet):
            break
        case .server(let virtualStage):
            stageObject = virtualStage.object
            snapshotObject.Stage = stageObject!
        }
        
        snapshotObject.saveInBackground { success, error in
            if let error = error {
                self.delegate?.rendererDidEncounterNetwordError(self)
            }
        }
    }
    
    func configureARSession(state: VSSession.SessionState, resetTracking: Bool = false) {
        let config = ARWorldTrackingConfiguration()
        config.environmentTexturing = .none
        
        switch state {
        case .initializing:
            config.planeDetection = .horizontal
        case .pickingSet:
            config.planeDetection = .horizontal
        case .exploringScene(_):
            if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) {
                config.frameSemantics.insert(.personSegmentationWithDepth)
            }
            /*
            if ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth) {
                config.frameSemantics.insert(.smoothedSceneDepth)
            }*/
            config.planeDetection = .horizontal
        case .loadingModel:
            config.planeDetection = .horizontal
        }
        
        
        
        
        arView.session.run(config, options: resetTracking ? [.resetTracking, .removeExistingAnchors] : [])
    }
    
    private func prepareRecorder(device: MTLDevice, width: Int, height: Int, _ completion: @escaping (Recorder, MTLTexture) -> Void) {
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.width = width
        textureDescriptor.height = height
        textureDescriptor.pixelFormat = .bgra8Unorm_srgb
        textureDescriptor.textureType = .type2D
        textureDescriptor.mipmapLevelCount = 2
        
        DispatchQueue.global(qos: .userInitiated).async {
            let texture = device.makeTexture(descriptor: textureDescriptor)!
            let recorder = Recorder(width: self.textureWidth!, height: self.textureHeight!)!
            
            completion(recorder, texture)
        }
    }
    
    private func initializeWatchTexture(device: MTLDevice, width: Int, height: Int, _ completion: @escaping (MTLTexture) -> Void) {
        os_log(.info, "Initializing watch texture")
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.width = width
        textureDescriptor.height = height
        textureDescriptor.pixelFormat = .bgra8Unorm_srgb
        textureDescriptor.textureType = .type2D
        textureDescriptor.usage = .shaderRead
        
        let desc = MTLTextureDescriptor()
        desc.width = width
        desc.height = height
        desc.pixelFormat = .rgba8Unorm
        desc.textureType = .type2D
        desc.mipmapLevelCount = 6
        desc.usage = .shaderWrite
        
        DispatchQueue.global(qos: .userInitiated).async {
            let texture = device.makeTexture(descriptor: textureDescriptor)!
            let rgbaTex = device.makeTexture(descriptor: desc)!
            self.watchRGBATexture = rgbaTex
            completion(texture)
        }
    }
    
    private func prepareWithDevice(_ device: MTLDevice) {
        self.device = device
    }
    
    private func postProcess(_ context: ARView.PostProcessContext) {
        /*
        if self.bloomTexture == nil {
            self.bloomTexture = self.makeTexture(matching: context.sourceColorTexture)
        }
        
        let brightness = MPSImageThresholdToZero(device: device, thresholdValue: 0.2, linearGrayColorTransform: nil)
        brightness.encode(commandBuffer: context.commandBuffer, sourceTexture: context.sourceColorTexture, destinationTexture: bloomTexture!)
        
        
        let gussianBlur = MPSImageGaussianBlur(device: device, sigma: 0.9)
        gussianBlur.encode(commandBuffer: context.commandBuffer, inPlaceTexture: &bloomTexture) */
        /*
        let median = MPSImageMedian(device: device, kernelDiameter: 7)
        median.encode(commandBuffer: context.commandBuffer, sourceTexture: context.sourceColorTexture, destinationTexture: context.targetColorTexture)
        */
        /*
        let gussianBlur = MPSImageGaussianBlur(device: device, sigma: 0.5)
        gussianBlur.encode(commandBuffer: context.commandBuffer, sourceTexture: context.sourceColorTexture, destinationTexture: context.targetColorTexture)
         */
        /*
        let sobel = MPSImageSobel(device: device)
        sobel.encode(commandBuffer: context.commandBuffer, sourceTexture: context.sourceColorTexture, destinationTexture: context.targetColorTexture)
         */
        /*
        let imageBox = MPSImageBox(device: device, kernelWidth: 5, kernelHeight: 5)
        imageBox.encode(commandBuffer: context.commandBuffer, sourceTexture: context.sourceColorTexture, destinationTexture: context.targetColorTexture)
         */
        /*
        let tent = MPSImageTent(device: device, kernelWidth: 7, kernelHeight: 7)
        tent.encode(commandBuffer: context.commandBuffer, sourceTexture: context.sourceColorTexture, destinationTexture: context.targetColorTexture)
         */
        /*
        let histoEqualizer = MPSImageHistogramEqualization(device: device)
        histoEqualizer.encode(commandBuffer: context.commandBuffer, sourceTexture: context.sourceColorTexture, destinationTexture: context.targetColorTexture)
         */
        
        /*
        let add = MPSImageAdd(device: device)
        add.encode(commandBuffer: context.commandBuffer, primaryTexture: context.sourceColorTexture, secondaryTexture: bloomTexture!, destinationTexture: context.targetColorTexture)
        */
        /*
        var value: Float = 100.0
        let erode = MPSImageErode(device: device, kernelWidth: 7, kernelHeight: 7, values: &value)
        erode.encode(commandBuffer: context.commandBuffer, sourceTexture: context.sourceColorTexture, destinationTexture: context.targetColorTexture)
         */
        
        if (shouldSendWatchUpdates) { watchFrameCounter += 1 }
        textureWidth = context.sourceColorTexture.width
        textureHeight = context.sourceColorTexture.height
        
        let commandBuffer = context.commandBuffer
        
        commandBuffer.addCompletedHandler { _ in
            if let rgbaTex = self.watchRGBATexture, self.shouldSendWatchUpdates, (self.watchFrameCounter % 30) == 0  {
                let elapsed = self.recorder?.elapsed
                self.delegate?.rendererDidUpdate(self, watchTexture: rgbaTex, elapsed: elapsed)
            }
            if let recordingTexture = self.recordingTexture, let recorder = self.recorder, self.isRecording {
                recorder.update(renderedTexture: recordingTexture)
            }
            
            self.directionalLightAnchor?.transform = self.arView.cameraTransform
        }
        
        if let texture = self.watchRGBATexture, shouldSendWatchUpdates, (self.watchFrameCounter % 30) == 0 {
            let convert = MPSImageConversion.init(device: device)
            convert.encode(commandBuffer: commandBuffer, sourceTexture: context.sourceColorTexture, destinationTexture: texture)
            /*
            let encoder = commandBuffer.makeBlitCommandEncoder()!
            encoder.generateMipmaps(for: watchRGBATexture)
            encoder.endEncoding() */
            
        }
        
        let blitCommandEncoder = commandBuffer.makeBlitCommandEncoder()!
        if let recordingTexture = self.recordingTexture, isRecording {
            blitCommandEncoder.copy(from: context.sourceColorTexture, to: recordingTexture)
            blitCommandEncoder.generateMipmaps(for: recordingTexture)
        }
        if let watchTexture = self.watchRGBATexture, shouldSendWatchUpdates, (self.watchFrameCounter % 30) == 0 {
            //blitCommandEncoder.copy(from: context.sourceColorTexture, to: watchTexture)
            blitCommandEncoder.generateMipmaps(for: watchTexture)
        }
        blitCommandEncoder.copy(from: context.sourceColorTexture, to: context.targetColorTexture)
        blitCommandEncoder.endEncoding()
        /*
        if let watchTexture = self.watchTexture, shouldSendWatchUpdates, (self.watchFrameCounter % 60) == 0 {
            let convert = MPSImageConversion.init(device: device)
            convert.encode(commandBuffer: commandBuffer, sourceTexture: watchTexture, destinationTexture: watchRGBATexture)
            /*
            let encoder = commandBuffer.makeBlitCommandEncoder()!
            encoder.generateMipmaps(for: watchRGBATexture)
            encoder.endEncoding() */
            
        } */
    }
}

extension ARViewRenderer: RecorderDelegate {
    func recorderDidFinishSavingRecording(_ recorder: Recorder) {
        delegate?.recorder(recorder, didFinishWritingVideo: true)
    }
}

protocol ARViewRendererDelegate: AnyObject {
    func recorder(_ recorder: Recorder, didFinishWritingVideo: Bool)
    func renderer(_ renderer: ARViewRenderer, didSaveSnapshot: Bool)
    func rendererDidUpdate(_ renderer: ARViewRenderer, watchTexture: MTLTexture, elapsed: TimeInterval?)
    func rendererDidUpdateWatchTexture(_ renderer: ARViewRenderer, width: Int, height: Int)
    func rendererDidEncounterNetwordError(_ renderer: ARViewRenderer)
    func rendererTrackingStateDidChange(_ renderer: ARViewRenderer, isTracking: Bool)
}

protocol ARViewRendererDataSource: AnyObject {
    func currentStagePreview() -> SetPreview
}

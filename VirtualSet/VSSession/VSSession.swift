//
//  VSSession.swift
//  VirtualSet
//
//  Created by Reza on 9/3/21.
//

import Foundation
import Combine
import RealityKit
import ARKit
import os.signpost
import SwiftUI
import Parse
import Bolts
import WatchConnectivity
import SpriteKit

/// - Tag: Virtual Set Session Class
final class VSSession: NSObject, ObservableObject {
    // MARK: - Properties
    var sceneLoader: SceneLoader
    var arViewRenderer: ARViewRenderer!
    var arView: ARView? {
        didSet {
            configureARViewRenderer(arView!)
        }
    }
    var coachingOverlay: ARCoachingOverlayView! {
        didSet {
            guard arView != nil else { return }
            
            coachingOverlay.session = arView!.session
        }
    }
    
    /// Reflects the current state of the user experience to update the user interface accordingly
    @Published var state: SessionState = .initializing {
        didSet {
            guard oldValue != state else { return }
            
            respondToStateChange(previous: oldValue, current: state)
            
            os_log(.info, "state changed: %s" ,"\(state)")
        }
    }
    
    /// Keep track of recording status
    @Published var isRecording: Bool = false {
        didSet {
            guard oldValue != isRecording else { return }
            
            state = .exploringScene(isRecording ? .recording : .viewing)
        }
    }
    
    @Published var isAuthorized: Bool = false {
        didSet {
            guard oldValue != isAuthorized else { return }
            
            if isAuthorized, state == .initializing {
                state = .pickingSet
            }
        }
    }
    
    @Published var isDeviceSupported: Bool = true
    
    @Published var setPreviews: [SetPreview] = []
    
    @Published var hints: [Hint] = []
    
    @Published var showHintReply: Bool = false
    
    @Published var announcement: String?
    
    @Published var tip: String?
    
    @Published var shouldShowNetworkError: Bool = false
    
    var longPressed: Bool = false
    
    private var streams = [AnyCancellable]()
    
    /// Keeps track of currently active
    var activeStage: Entity?
    var activePreview: SetPreview?
    
    var shouldShowTransformHint: Bool {
        let defaults = UserDefaults.standard
        return !defaults.bool(forKey: "TransformHint")
    }
    
    /// Watch connectivity
    var watchSession: WatchSession?
    
    var searchBarTimer: Timer?
    
    // server connection
    var pingTask: URLSessionDataTask?
    
    @Published var allowCoachingViewHitTesting: Bool = false
    
    // MARK: - Initializatin
    override init() {
        sceneLoader = SceneLoader()
        super.init()
        
        let parseConfig = ParseClientConfiguration {
            $0.isLocalDatastoreEnabled = true
            $0.applicationId = "MtaXFYdY0xTc0IUgThYwjhiXHMzIHroG0XLA4ioC"
            $0.clientKey = "VUi9YWat10vsxMwl26p7sdEwRqjNdgE1FtBGeFgw"
            $0.server = "https://dynamicstacks.net/parse"
        }
        Parse.initialize(with: parseConfig)
        PFVirtualStage.registerSubclass()
        PFVideoRecordings.registerSubclass()
        PFSnapshot.registerSubclass()
        
        determineAuthorizationStatus()
        
        if WCSession.isSupported() {
            watchSession = WatchSession()
            watchSession?.dataSource = self
            watchSession?.delegate = self
        }
        
        //checkServerConnection()
        
    }
    
    // MARK: - Methods
    func checkServerConnection() {
        // Check Connection to server
        let urlSession = URLSession.shared
        let url = URL(string: "https://dynamicstacks.net/parse")!
        let request = URLRequest(url: url, timeoutInterval: 5.0)
        pingTask = urlSession.dataTask(with: request) { data, response, error in
            if let data = data {
                
            }
            if let response = response {
                
            }
            if let error = error {
                self.showNetworkError()
                
            }
        }
        pingTask!.resume()
    }
    func requestAuthorization() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        default:
            AVCaptureDevice.requestAccess(for: .video) { isGranted in
                if isGranted {
                    switch AVCaptureDevice.authorizationStatus(for: .audio) {
                    case .authorized:
                        DispatchQueue.main.async {
                            self.isAuthorized = true
                        }
                    default:
                        AVCaptureDevice.requestAccess(for: .audio) { isAudioGranted in
                            if isAudioGranted {
                                DispatchQueue.main.async {
                                    self.isAuthorized = true
                                }
                            } else {
                                DispatchQueue.main.async {
                                    self.isAuthorized = false
                                }
                            }
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        self.isAuthorized = false
                    }
                }
            }
        }
    }
    
    func determineAuthorizationStatus() {
        var isVideoAuthorized: Bool = false
        var isMicrophoneAuthorized: Bool = false
        
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isVideoAuthorized = true
        default:
            break
        }
        
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            isMicrophoneAuthorized = true
        default:
            break
        }
        
        isAuthorized = (isVideoAuthorized && isMicrophoneAuthorized)
    }
    func configureARViewRenderer(_ arView: ARView) {
        arViewRenderer = ARViewRenderer(arView, isRecording: $isRecording)
        arViewRenderer.delegate = self
        arViewRenderer.dataSource = self
        arViewRenderer.shouldSendWatchUpdates = watchSession?.session.isReachable ?? false
        coachingOverlay?.session = arView.session
        arViewRenderer.configureARSession(state: state)
    }
    
    // MARK: - User Interaction
    func searchTermChanged(newValue: String) {
        guard newValue != "" else { return }
        
        // Reset Timeer
        let timerBlock: (Timer) -> Void = { timer in
            let searchTermObject = PFSearchedTerm()
            searchTermObject.IsLandscape = UIDevice.current.orientation.isLandscape
            searchTermObject.SearchedString = newValue
            searchTermObject.saveInBackground { [weak self] succeed, error in
                if let error = error {
                    os_log(.error, "error saving search term object: %s", "\(error)")
                    self?.showNetworkError()
                } else {
                    os_log(.info, "saved search term object")
                }
            }
        }
        resetTimer(block: timerBlock, countDown: 1.0)
    }
    
    private func resetTimer(block: @escaping (Timer) -> Void, countDown: Double) {
        searchBarTimer?.invalidate()
        searchBarTimer = Timer.init(timeInterval: countDown, repeats: false, block: block)
        RunLoop.main.add(searchBarTimer!, forMode: .default)
    }
    
    func resetTracking() {
        arViewRenderer?.configureARSession(state: state, resetTracking: true)
    }
    func userDidPickSet(_ set: SetPreview) {
        self.activePreview = set
        
        switch set.source {
        case .bundle(let bundleSet):
            
            DispatchQueue.main.async {
                withAnimation {
                    self.state = .loadingModel
                }
            }
            
            sceneLoader.loadBundleSet(bundleSet) { stage, sphere, error in
                guard error == nil else { fatalError() }
                
                #if !targetEnvironment(simulator)
                self.arViewRenderer.addStage(stage!, environment: sphere)
                #endif
                
                DispatchQueue.main.async {
                    withAnimation {
                        self.state = .exploringScene(.viewing)
                    }
                }
            }
        case .server(let virtualStage):
            guard let setURL = virtualStage.modelURL else { fatalError() }
            DispatchQueue.main.async {
                withAnimation {
                    self.state = .loadingModel
                }
            }
            
            let request = Entity.loadAsync(contentsOf: setURL, withName: virtualStage.name + ".reality")
            let cancellable = request
                .receive(on: DispatchQueue.main, options: nil)
                .sink { loadCompletion in
                    if case let .failure(error) = loadCompletion {
                        os_log(.error, "error loading virtual stage model from disk: %s" ,"\(error)")
                    }
                } receiveValue: { entity in
                    var sphereEntity: ModelEntity?
                    
                    if let skyboxURL = virtualStage.skyboxURL {
                        let sphereMesh = MeshResource.generateSphere(radius: 600.0)
                        var material = PhysicallyBasedMaterial()
                        do {
                            let textureResource = try TextureResource.load(contentsOf: skyboxURL, withName: nil)
                            let texture = MaterialParameters.Texture.init(textureResource)
                            material.baseColor = PhysicallyBasedMaterial.BaseColor(tint: UIColor.white, texture: texture)
                            material.emissiveColor = PhysicallyBasedMaterial.EmissiveColor(color: .init(white: 0.2, alpha: 1.0), texture: texture)
                            material.emissiveIntensity = 1.0
                            material.faceCulling = .none
                            let sphere = ModelEntity(mesh: sphereMesh, materials: [material])
                            sphereEntity = sphere
                        } catch {
                            os_log(.error, "error creating skybox from url: %s", "\(error)")
                        }
                    }
                    
                    self.arViewRenderer.addStage(entity, environment: sphereEntity)
                    DispatchQueue.main.async {
                        withAnimation {
                            self.state = .exploringScene(.viewing)
                        }
                    }
                    os_log(.info, "created entity from downloaded data")
                }
            cancellable.store(in: &self.streams)
        }
    }
    
    // Gestues
    /// Draging to translate
    func translateSet(value: DragGesture.Value) {
        guard !isRecording else { return }
        #if !targetEnvironment(simulator)
        arViewRenderer.translateSet(value: value)
        #endif
    }
    
    func commitTranslation(endValue: DragGesture.Value) {
        guard !isRecording else { return }
        #if !targetEnvironment(simulator)
        arViewRenderer.commitSetTranslation(value: endValue)
        #endif
    }
    
    /// Pinching to scale
    func scaleSet(magnitude: CGFloat) {
        guard !isRecording else { return }
        #if !targetEnvironment(simulator)
        arViewRenderer.scaleSet(magnitude: magnitude)
        #endif
    }
    
    func commitScaleSet(endMagnitude: CGFloat) {
        guard !isRecording else { return }
        #if !targetEnvironment(simulator)
        arViewRenderer.commitScaleSet(endMagnitude: endMagnitude)
        #endif
    }
    
    // Rotation
    func rotateSet(angle: RotationGesture.Value) {
        guard !isRecording else { return }
        #if !targetEnvironment(simulator)
        arViewRenderer.rotateSet(angle: angle)
        #endif
    }
    
    func commitRotateSet(angle: RotationGesture.Value) {
        guard !isRecording else { return }
        #if !targetEnvironment(simulator)
        arViewRenderer.commitRotateSet(angle: angle)
        #endif
    }
    
    func rotateAndScale(angle: RotationGesture.Value, magnitude: MagnificationGesture.Value) {
        guard !isRecording else { return }
        #if !targetEnvironment(simulator)
        arViewRenderer.scaleAndRotate(angle: angle, magnitude: magnitude)
        #endif
    }
    
    func anchorStageAtPoint(_ point: CGPoint) {
        #if !targetEnvironment(simulator)
        arViewRenderer.anchorSetAtPoint(point)
        #endif
    }
    
    func takePhoto() {
        arViewRenderer?.snapshot()
    }
    
    func didPickImage(_ image: UIImage) {
        arViewRenderer?.addImage(image)
    }
    
    func handleTap(location: CGPoint) {
        arViewRenderer?.selectEntityAt(location)
        
        if longPressed {
            arViewRenderer?.removeSelectedImageEntity()
            longPressed = false
        }
    }
    
    // MARK: - Helper Methods
    func showNetworkError() {
        let when = DispatchTime.now() + kNetworkErrorDuration
        DispatchQueue.main.async {
            withAnimation {
                self.shouldShowNetworkError = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: when) {
            withAnimation {
                self.shouldShowNetworkError = false
            }
        }
    }
    func displayHint() {
        let when = DispatchTime.now() + 5.0
        DispatchQueue.main.asyncAfter(deadline: when) {
            withAnimation {
                self.hints.append(Hint("Positioning: You can  position the scene with tap, hold and drag gesture\n\nScale: Scale the scene larger or smaller with pinch in or out"))
            }
        }
        
        // Show Hint Reply
        DispatchQueue.main.asyncAfter(deadline: when + kReplyDialogueDelay) {
            withAnimation {
                self.showHintReply = true
            }
        }
    }
    
    private func deviceSupported() -> Bool {
        return ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth)
    }
    
    func removeHint() {
        withAnimation {
            let _ = self.hints.removeLast()
            showHintReply = false
        }
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: "TransformHint")
        
        if !deviceSupported() {
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 21.0, execute: { self.isDeviceSupported = false })
            showDeviceNotSupportedHint()
        }
    }
    
    func showDeviceNotSupportedHint(delay: Double = 5.0) {
        guard hints.isEmpty else { return }
        
        let when = DispatchTime.now() + delay
        DispatchQueue.main.asyncAfter(deadline: when) {
            withAnimation {
                self.hints.append(Hint("People Occlusion is not supported on this device! you will not be able to see people inside 3D scenes. Use a device with the A12 chip or later to utilize all features of XR Filming."))
            }
        }
        
        // Show Hint Reply
        DispatchQueue.main.asyncAfter(deadline: when + 15.0) {
            withAnimation {
                let _ = self.hints.removeLast()
            }
        }
    }
    
    func respondToStateChange(previous: SessionState, current: SessionState) {
        // Broadcast status change to watch
        watchSession?.broadcastStatusChange(current)
        if previous == .loadingModel { tip = nil }
        switch current {
        case .initializing:
            break
        case .pickingSet:
            
            arViewRenderer?.clearScene()
            
            activeStage = nil
            activePreview = nil
            setPreviews.removeAll()
            arViewRenderer?.shouldSendWatchUpdates = false
            
            checkServerConnection()
            sceneLoader.loadBundleVirtualSets { sets in
                DispatchQueue.main.async {
                    sets.forEach {
                        let preview = SetPreview(set: $0)
                        self.setPreviews.append(preview)
                        self.setPreviews.sort(by: {$0.id < $1.id})
                    }
                }
            }
            
            sceneLoader.loadDownloadedStages { stageInfos in
                self.sceneLoader.loadVirtualStages { objects, error in
                    if let virtualStageObjects = objects {
                        // Look for matching object ids in fetched and previously downloaded stages
                        // if object ids match check updatedAt values and if they match use the previously downloaded models
                        let previouslyDownloaded: [StageInfo] = virtualStageObjects.compactMap { virtualStageObject in
                            guard let id = virtualStageObject.objectId, let updatedAt = virtualStageObject.updatedAt else { return nil }
                            if let index = stageInfos.firstIndex(where: {$0.objectID == id}) {
                                os_log(.info, "object ids match checking updatedAt")
                                // compare updateAt
                                let matchingStageInfo = stageInfos[index]
                                if matchingStageInfo.updatedAt == updatedAt {
                                    return matchingStageInfo
                                }
                            }
                            return nil
                        }
                        // Filter virtual stage objects to exclude previously downloaded
                        let filteredVirtualStageObjects = virtualStageObjects.filter { virtualStage in
                            if previouslyDownloaded.contains(where: {$0.objectID == virtualStage.objectId!}) {
                                return false
                            }
                            return true
                        }
                        
                        // Create previews from previously downloaded
                        for downloadedSet in previouslyDownloaded {
                            if let object = virtualStageObjects.first(where: {$0.objectId! == downloadedSet.objectID}) {
                                let virtualStage = VirtualStage(object: object)
                                virtualStage.modelURL = downloadedSet.modelURL
                                if let skyboxURL = downloadedSet.skyboxURL {
                                    virtualStage.skyboxURL = skyboxURL
                                }
                                virtualStage.downloadDone = true
                                virtualStage.downloadInProgress = false
                                
                                var preview = SetPreview(set: virtualStage)
                                preview.downloaded = true
                                
                                self.setPreviews.append(preview)
                                self.setPreviews.sort(by: {$0.id < $1.id})
                            }
                        }
                        // Process objects that are not downloaded
                        filteredVirtualStageObjects.forEach {
                            let virtualStage = VirtualStage(object: $0)
                            let preview = SetPreview(set: virtualStage)
                            self.setPreviews.append(preview)
                            self.setPreviews.sort(by: {$0.id < $1.id})
                        }
                    } else if let error = error {
                        os_log(.error, "error fetching virtual stage objects: %s", "\(error)")
                    }
                }
            }
        case .exploringScene:
            if shouldShowTransformHint {
                displayHint()
            } else {
                isDeviceSupported = deviceSupported()
            }
            if !(arViewRenderer.isTrackingNormal && arViewRenderer.floorDetected) {
                coachingOverlay.setActive(true, animated: true)
            }
        case .loadingModel:
            setPreviews.removeAll()
            tip = "Tip: You can remove photographs by long tap"
        }
        
        arViewRenderer?.configureARSession(state: current)
    }
    
    func announce(_ text: String) {
        self.announcement = text
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + kAnnouncementTime + 3.0) {
            self.announcement = nil
        }
    }
}
extension VSSession: ARViewRendererDataSource {
    func currentStagePreview() -> SetPreview {
        return activePreview!
    }
}


// MARK: - Types
extension VSSession {
    enum SessionState {
        enum ExploringSceneState {
            case viewing
            case recording
        }
        
        case initializing
        case pickingSet
        case exploringScene(ExploringSceneState)
        case loadingModel
    }
}
extension VSSession.SessionState: Equatable {
    
}

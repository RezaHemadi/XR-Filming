//
//  SceneLoader.swift
//  VirtualSet
//
//  Created by Reza on 9/6/21.
//

import Foundation
import RealityKit
import Combine
import MetalKit
import ModelIO
import os.signpost
import Parse

let kModelsDirName: String = "Models"

/// - Tag: Object Responsible for Loading Virtual Scenes From App Bundle Or Remote Server
class SceneLoader {
    enum SceneLoaderError: Error {
        case invalidURL
    }
    // MARK: - Properties
    
    /// array to hold combine cancellables so as not to de-allocate them before they're done
    private var streams = [AnyCancellable]()
    
    
    func loadBundleVirtualSets(_ completion: @escaping ([BundleVirtualSet]) -> Void) {
        DispatchQueue.main.async {
            let sets: [BundleVirtualSet] = load(fileName: "BundleSets.json")
            completion(sets)
        }
    }
    
    static var modelsDir: URL {
        let fileManager = FileManager.default
        let docsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let modelsDir = docsURL.appendingPathComponent(kModelsDirName)
        return modelsDir
    }
    
    // MARK: - Initialization
    init() {
        let fileManager = FileManager.default
        let docsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let modelsDir = docsURL.appendingPathComponent(kModelsDirName)
        if fileManager.fileExists(atPath: modelsDir.path) {
        } else {
            try! fileManager.createDirectory(at: modelsDir, withIntermediateDirectories: true, attributes: nil)
        }
    }
    
    // MARK: - Interface Methods
    func loadVirtualStages(_ completion: @escaping ([PFVirtualStage]?, Error?) -> Void) {
        #if !targetEnvironment(simulator)
        let query = PFVirtualStage.query()!
        query.findObjectsInBackground(block: { objects, error in
            if error == nil, let stageObjects = objects as? [PFVirtualStage] {
                os_log(.info, "fetched virtual stage objects: \n%s", "\(stageObjects)")
                completion(stageObjects, nil)
            } else if let error = error {
                os_log(.error, "error fetching virtual stage objects: %s", "\(error)")
                completion(nil, error)
            }
        })
        #endif
    }
    private func loadRealityComposerSceneAsync (filename: String,
                                        fileExtension: String,
                                        sceneName: String,
                                        completion: @escaping (Swift.Result<Entity?, Swift.Error>) -> Void) {
        
        guard let realityFileSceneURL = SceneLoader.createRealityURL(filename: filename, fileExtension: fileExtension, sceneName: sceneName) else {
            print("Error: Unable to find specified file in application bundle")
            return
        }
        
        let loadRequest = Entity.loadAnchorAsync(contentsOf: realityFileSceneURL)
        let cancellable = loadRequest
            .receive(on: DispatchQueue.main, options: nil)
            .sink(receiveCompletion: { (loadCompletion) in
            if case let .failure(error) = loadCompletion {
                completion(.failure(error))
            }
        }, receiveValue: { (entity) in
            completion(.success(entity))
        })
        cancellable.store(in: &streams)
    }
    
    func loadDownloadedStages(_ completion: @escaping ([StageInfo]) -> Void) {
        var stages: [StageInfo] = []
        DispatchQueue.global(qos: .userInitiated).async {
            let fileManager = FileManager.default
            let root = SceneLoader.modelsDir
            do {
                let urls = try fileManager.contentsOfDirectory(atPath: root.path)
                os_log(.info, "root urls\n%s", "\(urls)")
                for subPath in urls {
                    let infoFileURL = root.appendingPathComponent(subPath).appendingPathComponent("info").appendingPathExtension("JSON")
                    if fileManager.fileExists(atPath: infoFileURL.path) {
                        let infoData = try Data(contentsOf: infoFileURL)
                        let decoder = JSONDecoder()
                        let info = try decoder.decode(StageInfo.self, from: infoData)
                        stages.append(info)
                    }
                }
            } catch {
                os_log(.error, "error loading downloaded stages info: %s", "\(error)")
            }
            completion(stages)
        }
    }
    
    class func createRealityURL(filename: String,
                                  fileExtension: String,
                                  sceneName:String) -> URL? {
                // Create a URL that points to the specified Reality file.
                guard let realityFileURL = Bundle.main.url(forResource: filename,
                                                           withExtension: fileExtension) else {
                    print("Error finding Reality file \(filename).\(fileExtension)")
                    return nil
                }

                // Append the scene name to the URL to point to
                // a single scene within the file.
                let realityFileSceneURL = realityFileURL.appendingPathComponent(sceneName,
                                                                                isDirectory: false)
                return realityFileSceneURL
    }
    
    func loadBundleSet(_ set: BundleVirtualSet, _ completion: @escaping (Entity?, ModelEntity?, Error?) -> Void) {
        guard let url = Bundle.main.url(forResource: set.name, withExtension: "reality") else {
            let error = SceneLoaderError.invalidURL
            completion(nil, nil, error)
            return
        }
        
        let cancellable = Entity.loadAsync(contentsOf: url, withName: set.name)
            .sink(receiveCompletion: { loadCompletion in
                // Handle error
                if case let .failure(error) = loadCompletion {
                    os_log(.error, "error loading file: %s", "\(error)")
                    completion(nil, nil, error)
                }
            }, receiveValue: { entity in
                
                if let environmentMap = set.environmentMap {
                    let sphere = SceneLoader.createEnvMapSphereEntity(envMapName: environmentMap)
                    completion(entity, sphere, nil)
                } else {
                    completion(entity, nil, nil)
                }
            })
        cancellable.store(in: &streams)
    }
    
    class func createEnvMapSphereEntity(envMapName: String) -> ModelEntity? {
        let sphereMesh = MeshResource.generateSphere(radius: 600.0)
        var material = PhysicallyBasedMaterial()
        do {
            let textureResource = try TextureResource.load(named: envMapName)
            let texture = MaterialParameters.Texture.init(textureResource)
            material.baseColor = PhysicallyBasedMaterial.BaseColor(tint: UIColor.white, texture: texture)
            material.emissiveColor = PhysicallyBasedMaterial.EmissiveColor(color: .init(white: 0.2, alpha: 1.0), texture: texture)
            material.emissiveIntensity = 1.0
            material.faceCulling = .none
            let sphere = ModelEntity(mesh: sphereMesh, materials: [material])
            return sphere
        } catch {
            return nil
        }
    }
}

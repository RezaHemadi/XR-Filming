//
//  SceneLoader.swift
//  VirtualSet
//
//  Created by Reza on 9/6/21.
//

import Foundation
import RealityKit
import Combine
import os.signpost

/// - Tag: Object Responsible for Loading Virtual Scenes From App Bundle Or Remote Server
class SceneLoader: ObservableObject {
    // MARK: - Properties
    
    /// scenes included in the app bundle
    @Published var bundleVirtualSets = [BundleVirtualSet]()
    
    /// array to hold combine cancellables so as not to de-allocate them before they're done
    private var streams = [AnyCancellable]()
    
    // MARK: - Initialization
    init() {
        loadBundleVirtualSets { sets in
            for set in sets {
                self.bundleVirtualSets.append(set)
            }
        }
    }
    
    // MARK: - Private Methods
    private func loadBundleVirtualSets(_ completion: @escaping ([BundleVirtualSet]) -> Void) {
        DispatchQueue.global(qos: .background).async {
            let sets: [BundleVirtualSet] = load(fileName: "BundleSets.json")
            completion(sets)
        }
    }
    
    private func loadRealityComposerSceneAsync (filename: String,
                                        fileExtension: String,
                                        sceneName: String,
                                        completion: @escaping (Swift.Result<Stage?, Swift.Error>) -> Void) {
        
        guard let realityFileSceneURL = SceneLoader.createRealityURL(filename: filename, fileExtension: fileExtension, sceneName: sceneName) else {
            print("Error: Unable to find specified file in application bundle")
            return
        }
        
        let loadRequest = Entity.loadAnchorAsync(contentsOf: realityFileSceneURL)
        let cancellable = loadRequest.sink(receiveCompletion: { (loadCompletion) in
            if case let .failure(error) = loadCompletion {
                completion(.failure(error))
            }
        }, receiveValue: { (entity) in
            completion(.success(entity))
        })
        cancellable.store(in: &streams)
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
    
    // MARK: - Interface Methods
    func loadBundleSet(_ set: BundleVirtualSet, _ completion: @escaping ((Entity & HasAnchoring)?, Error?) -> Void) {
        loadRealityComposerSceneAsync(filename: "Experience", fileExtension: "reality", sceneName: set.name) { result in
            switch result {
            case .success(let entity):
                completion(entity, nil)
            case .failure(let error):
                os_log(.error, "error loading reality composer file: %s", "\(error.localizedDescription)")
                completion(nil, error)
            }
        }
    }
}

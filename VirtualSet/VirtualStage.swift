//
//  VirtualStage.swift
//  VirtualSet
//
//  Created by Reza on 11/6/21.
//  Copyright © 2021 Dynamic Stacks LTD. All rights reserved.
//

import Foundation
import UIKit
import RealityKit
import os.signpost
import Combine

class VirtualStage: ObservableObject {
    var object: PFVirtualStage
    
    @Published var thumbnail: UIImage?
    var name: String {
        return object.Name
    }
    var attribution: String {
        return object.Attribution
    }
    var order: Int {
        return object.Order.intValue
    }
    
    var modelURL: URL?
    var skyboxURL: URL?
    
    var streams: [AnyCancellable] = []
    
    @Published var modelDownloadProgress: Int32 = 0
    @Published var skyboxDownloadProgress: Int32 = 0
    @Published var progress: Double = 0
    @Published var downloadDone: Bool = false
    @Published var modelDownloaded: Bool = false
    @Published var skyboxDownloaded: Bool = false
    @Published var downloadInProgress: Bool = false
    
    var downloadProgress: AnyPublisher<Int32, Never> {
        if object.EnvironmentMap == nil {
            return $modelDownloadProgress.eraseToAnyPublisher()
        } else {
            return Publishers.CombineLatest($modelDownloadProgress, $skyboxDownloadProgress).map { progOne, progTwo in
                return ((progOne + progTwo) / 2)
            }
            .eraseToAnyPublisher()
        }
    }
    
    var downloadCompletion: AnyPublisher<Bool, Never> {
        if object.EnvironmentMap == nil {
            return $modelDownloaded.eraseToAnyPublisher()
        } else {
            return Publishers.Zip($modelDownloaded, $skyboxDownloaded).map { modelCompleted, skyboxCompleted in
                return (modelCompleted && skyboxCompleted)
            }
            .eraseToAnyPublisher()
        }
    }
   
    init(object: PFVirtualStage) {
        self.object = object
        
        let stream = downloadProgress.sink { value in
            self.progress = Double(value)
        }
        stream.store(in: &streams)
        
        let dlCompletionStream = downloadCompletion.sink { completed in
            self.downloadDone = completed
            self.downloadInProgress = false
        }
        dlCompletionStream.store(in: &streams)
    }
    
    func download() {
        downloadInProgress = true
        if let skyboxFile = object.EnvironmentMap {
            let remoteURL = URL(string: skyboxFile.url!)!
            let pathExtension = remoteURL.pathExtension
            skyboxFile.getDataInBackground { data, error in
                if error == nil, let data = data {
                    let modelsDir = SceneLoader.modelsDir
                    let fileManager = FileManager.default
                    let setDir = modelsDir.appendingPathComponent(self.name.whiteSpacesRemoved)
                    if fileManager.fileExists(atPath: setDir.path) {
                        // set directory exists
                        // update model
                    } else {
                        // set directory does not exist
                        // create directory for set
                        try! fileManager.createDirectory(at: setDir, withIntermediateDirectories: true, attributes: nil)
                    }
                    
                    let skyboxURL = setDir.appendingPathComponent("skybox").appendingPathExtension(pathExtension)
                    let skyboxFile = fileManager.createFile(atPath: skyboxURL.path, contents: data, attributes: nil)
                    
                    if skyboxFile {
                        self.skyboxURL = skyboxURL
                        self.skyboxDownloaded = true
                    }
                }
            } progressBlock: { progressValue in
                self.skyboxDownloadProgress = progressValue
            }

        }
        
        object.Model.getDataInBackground( { data, error in
            if error == nil, let data = data {
                os_log(.info, "downloaded model: %s" ,"\(data)")
                let modelsDir = SceneLoader.modelsDir
                let fileManager = FileManager.default
                let setDir = modelsDir.appendingPathComponent(self.name.whiteSpacesRemoved)
                if fileManager.fileExists(atPath: setDir.path) {
                    // set directory exists
                    // update model
                } else {
                    // set directory does not exist
                    // create directory for set
                    try! fileManager.createDirectory(at: setDir, withIntermediateDirectories: true, attributes: nil)
                }
                
                let setURL = setDir.appendingPathComponent(self.name.whiteSpacesRemoved).appendingPathExtension("reality")
                let setFile = fileManager.createFile(atPath: setURL.path, contents: data, attributes: nil)
                
                if setFile {
                    // save stage info to disk
                    let stageInfo = StageInfo(name: self.object.Name, updatedAt: self.object.updatedAt!, objectID: self.object.objectId!)
                    let encoder = JSONEncoder()
                    do {
                        let stageInfoData = try encoder.encode(stageInfo)
                        let stageInfoURL = setDir.appendingPathComponent("info").appendingPathExtension("JSON")
                        let stageInfoFile = fileManager.createFile(atPath: stageInfoURL.path, contents: stageInfoData, attributes: nil)
                        if stageInfoFile {
                            os_log(.info, "saved stage info file to disk at path: %s", "\(stageInfoURL.path)")
                        }
                    } catch {
                        os_log(.error, "error saving stage info to disk: %s", "\(error)")
                    }
                } else {
                    os_log(.error, "error saving stage data to disk.")
                }
                
                self.modelURL = setURL
                self.modelDownloaded = true
                //completion(data, nil)
            } else if let error = error {
                os_log(.error, "error fetching model data: %s", "\(error)")
                //completion(nil, error)
            }
        }) { downloadProgress in
            self.modelDownloadProgress = downloadProgress
            //progress(downloadProgress)
        }
    }
    
    func downloadModel(_ completion: @escaping (_ modelData: Data?, _ error: Error?) -> Void, progress: @escaping (Int32) -> Void) {
        object.Model.getDataInBackground( { data, error in
            if error == nil, let data = data {
                os_log(.info, "downloaded model: %s" ,"\(data)")
                let modelsDir = SceneLoader.modelsDir
                let fileManager = FileManager.default
                let setDir = modelsDir.appendingPathComponent(self.name.whiteSpacesRemoved)
                if fileManager.fileExists(atPath: setDir.path) {
                    // set directory exists
                    // update model
                } else {
                    // set directory does not exist
                    // create directory for set
                    try! fileManager.createDirectory(at: setDir, withIntermediateDirectories: true, attributes: nil)
                }
                
                let setURL = setDir.appendingPathComponent(self.name.whiteSpacesRemoved).appendingPathExtension("reality")
                let setFile = fileManager.createFile(atPath: setURL.path, contents: data, attributes: nil)
                
                if setFile {
                    // save stage info to disk
                    let stageInfo = StageInfo(name: self.object.Name, updatedAt: self.object.updatedAt!, objectID: self.object.objectId!)
                    let encoder = JSONEncoder()
                    do {
                        let stageInfoData = try encoder.encode(stageInfo)
                        let stageInfoURL = setDir.appendingPathComponent("info").appendingPathExtension("JSON")
                        let stageInfoFile = fileManager.createFile(atPath: stageInfoURL.path, contents: stageInfoData, attributes: nil)
                        if stageInfoFile {
                            os_log(.info, "saved stage info file to disk at path: %s", "\(stageInfoURL.path)")
                        }
                    } catch {
                        os_log(.error, "error saving stage info to disk: %s", "\(error)")
                    }
                } else {
                    os_log(.error, "error saving stage data to disk.")
                }
                
                self.modelURL = setURL
                completion(data, nil)
            } else if let error = error {
                os_log(.error, "error fetching model data: %s", "\(error)")
                completion(nil, error)
            }
        }) { downloadProgress in
            self.modelDownloadProgress = downloadProgress
            progress(downloadProgress)
        }
    }
}

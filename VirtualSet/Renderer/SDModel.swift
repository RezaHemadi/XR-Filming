//
//  SDModel.swift
//  VirtualSet
//
//  Created by Reza on 9/22/21.
//

import Foundation
import MetalKit
import ARKit
import os.signpost


let kMaxRenderingOrder = 100
let kGenerateAO = false

/// - TAG: SDModel Class
class SDModel {
    // MARK: - Properties
    private let asset: MDLAsset
    let device: MTLDevice
    var meshTransformsBuffer: MTLBuffer!
    
    // Model Data
    var meshes = [SDMesh]()
    
    // Skeletal Animations
    var sampleTimes: [Double] = []
    
    
    // MARK: - Initialization
    init(asset: MDLAsset, device: MTLDevice, vertexDescriptor: MDLVertexDescriptor) {
        self.asset = asset
        self.device = device
        asset.loadTextures()
        
        var meshes = [SDMesh]()
        
        for index in 0..<asset.count {
            let object = asset[index]
            var stopPointer: ObjCBool = false
            // Process asset hierarchy
            let block: (MDLObject, UnsafeMutablePointer<ObjCBool>) -> Void = { object, stopPointer in
                if let mdlMesh = object as? MDLMesh {
                    let boundingBox = mdlMesh.boundingBox.maxBounds
                    // Add Tangents based on texture coordinates
                    mdlMesh.addTangentBasis(forTextureCoordinateAttributeNamed: MDLVertexAttributeTextureCoordinate,
                                            normalAttributeNamed: MDLVertexAttributeNormal,
                                            tangentAttributeNamed: MDLVertexAttributeTangent)
                    
                    // create bitangents from mesh texture coordinates and the newly created tangents
                    mdlMesh.addTangentBasis(forTextureCoordinateAttributeNamed: MDLVertexAttributeTextureCoordinate,
                                         tangentAttributeNamed: MDLVertexAttributeTangent,
                                         bitangentAttributeNamed: MDLVertexAttributeBitangent)
                    if kGenerateAO {
                        mdlMesh.generateAmbientOcclusionVertexColors(withQuality: 1.0,
                                                                     attenuationFactor: 1.0,
                                                                     objectsToConsider: [asset.object(at: 0)],
                                                                     vertexAttributeNamed: MDLVertexAttributeOcclusionValue)
                    }
                    
                    mdlMesh.vertexDescriptor = vertexDescriptor
           
                    // Make MTKMesh
                    let mesh = try! MTKMesh(mesh: mdlMesh, device: device)
                    
                    var rootTransform = matrix_identity_float4x4
                    rootTransform = simd_mul(mdlMesh.transform!.matrix, rootTransform)
                    
                    var parentObject = mdlMesh.parent
                    while (parentObject != nil) {
                        defer { parentObject = parentObject?.parent }
                        
                        guard let transform = parentObject!.transform else { continue }
                        
                        rootTransform = simd_mul(transform.matrix, rootTransform)
                    }
                    
                    let myMesh = SDMesh(mesh: mesh, transform: rootTransform, boundingBox: boundingBox)
                    
                    // Process texures
                    
                    mdlMesh.flipTextureCoordinates(inAttributeNamed: MDLVertexAttributeTextureCoordinate)
                    
                    if let submeshes = mdlMesh.submeshes {
                        for submesh in submeshes {
                            guard let material = (submesh as! MDLSubmesh).material else { continue }
                            
                            // Process Base Color Material
                            let baseColorProperties = material.properties(with: .baseColor)
                            myMesh.configureBaseColor(properties: baseColorProperties, device: device)
                            
                            // Process Metallic Property
                            let metallicProperties = material.properties(with: .metallic)
                            myMesh.configureMetallicProperty(properties: metallicProperties, device: device)
                            
                            // Process Specular Properties
                            
                            // spcular properties
                            let specularProperties = material.properties(with: .specular)
                            myMesh.configureSpecularMaterial(properties: specularProperties, device: device)
                            
                            
                            let specularExponentProperties = material.properties(with: .specularExponent)
                            myMesh.configureSpecularExponentMaterial(properties: specularExponentProperties, device: device)
                            
                            let specularTintProperties = material.properties(with: .specularTint)
                            myMesh.configureSpecularTintMaterial(properties: specularTintProperties, device: device)
                            
                            // Process roughness properties
                            /// Roughness is either texture or a float value
                            let roughnessProperties = material.properties(with: .roughness)
                            myMesh.configureRoughness(properties: roughnessProperties, device: device)
                            
                            // Related to Specular lighting
                            let anisotropicProperties = material.properties(with: .anisotropic)
                            myMesh.configureAnisotropicMaterial(properties: anisotropicProperties, device: device)
                            
                            let sheenProperties = material.properties(with: .sheen)
                            myMesh.configureSheenProperties(properties: sheenProperties, device: device)
                            
                            let sheenTintProperties = material.properties(with: .sheenTint)
                            myMesh.configureSheenTintProperties(properties: sheenTintProperties, device: device)
                            
                            let clearCoatProperties = material.properties(with: .clearcoat)
                            myMesh.configureClearCoatProperties(properties: clearCoatProperties, device: device)
                            
                            let clearCoatGlossProperties = material.properties(with: .clearcoatGloss)
                            myMesh.configureCoatGloassProperties(properties: clearCoatGlossProperties, device: device)
                            
                            let bumpProperties = material.properties(with: .bump)
                            myMesh.configureBumpProperties(properties: bumpProperties, device: device)
                            
                            // Process Opacity Texture
                            let opacityProperties = material.properties(with: .opacity)
                            myMesh.configureOpacity(properties: opacityProperties, device: device)
                            
                            let interfaceIndexOfRefractionProperties = material.properties(with: .materialIndexOfRefraction)
                            myMesh.configureInterfaceIndexOfRefraction(properties: interfaceIndexOfRefractionProperties, device: device)
                            
                            let objectSpaceNormalProperties = material.properties(with: .objectSpaceNormal)
                            myMesh.configureObjectSpaceNormalProperties(properties: objectSpaceNormalProperties, device: device)
                            
                            // Process Tangent SpaceNormals
                            let tangentSpaceProperties = material.properties(with: .tangentSpaceNormal)
                            myMesh.configureTangentSpaceNormal(properties: tangentSpaceProperties, device: device)
                            
                            let displacementProperties = material.properties(with: .displacement)
                            myMesh.configureDisplacementMaterial(properties: displacementProperties, device: device)
                            
                            let displacementScaleProperties = material.properties(with: .displacementScale)
                            myMesh.configureDisplacementScaleMaterial(properties: displacementScaleProperties, device: device)
                            
                            // Configure occlusion map
                            let ambientOcclusionProperties = material.properties(with: .ambientOcclusion)
                            myMesh.configureAmbientOcclusionMaterial(properties: ambientOcclusionProperties, device: device)
                            
                            let ambientOcclusionScaleProperties = material.properties(with: .ambientOcclusionScale)
                            myMesh.configureAmbientOcclusionScaleMaterial(properties: ambientOcclusionScaleProperties, device: device)
                            
                            let emissionMaterial = material.properties(with: .emission)
                            myMesh.configureEmissionMaterial(properties: emissionMaterial, device: device)
                        }
                    }
                    meshes.append(myMesh)
                }
                guard let animationBindComponent = object.componentConforming(to: MDLComponent.self) as? MDLAnimationBindComponent else  {
                    return
                }
                
                // Process Animation
                // setup the animated skeleton
                
                
                // only consider animations with a valid skeleton
                guard let skeleton = animationBindComponent.skeleton, !(skeleton.jointPaths.isEmpty) else {
                    print("Animation Bind Component is missing a skeleton or the jointPaths is empty")
                    return
                }
                // Process Skeleton and Animation
                
            }
            object!.enumerateChildObjects(of: MDLObject.self, root: object!, using: block, stopPointer: &stopPointer)
        }
        
        self.meshes = meshes
        
        // create buffer to hold mesh transforms
        let meshTransformsSize = MemoryLayout<matrix_float4x4>.size * meshes.count
        meshTransformsBuffer = device.makeBuffer(length: meshTransformsSize, options: .storageModeShared)
        for index in 0..<meshes.count {
            let offset = MemoryLayout<matrix_float4x4>.size * index
            meshTransformsBuffer.contents().advanced(by: offset).storeBytes(of: meshes[index].transform, as: matrix_float4x4.self)
        }
    }
    
    //MARK: - Animations
    func calculatePaletteMatrix(frameTime: Double) -> [matrix_float4x4]? {
        return nil
    }
    
    
    // MARK: - Methods
    func updateGameState(cameraTransform: matrix_float4x4, modelTransform: matrix_float4x4, deltaTime: TimeInterval) {
        // Update meshes rendering order
        var dictionary = [Int: Float]()
        
        // find each mesh'es distance to camera
        for index in 0..<meshes.count {
            // Ignore Opaque meshes
            guard !meshes[index].isOpaque else {
                meshes[index].renderingOrder = 0
                continue
            }
            
            let meshTransform = meshes[index].transform
            let meshBoundingBox = meshes[index].boundingBox
            
            // find camera distance to mesh
            let cameraTranslation = vector_float3([cameraTransform.columns.3.x, cameraTransform.columns.3.y, cameraTransform.columns.3.z])
            let modelTranslation = vector_float3([modelTransform.columns.3.x, modelTransform.columns.3.y, modelTransform.columns.3.z])
            // Get Mesh Transform in WorldSpace
            let meshWorldTransform = simd_mul(modelTransform, meshTransform)
            // Get Mesh Bounding Box in WorldSpace
            let meshModelBB = simd_mul(meshTransform, vector_float4([meshBoundingBox.x, meshBoundingBox.y, meshBoundingBox.z, 0.0]))
            // Get Camera Distance To Mesh World Position
            let meshWorldPos = vector_float3([meshWorldTransform.columns.3.x, meshWorldTransform.columns.3.y, meshWorldTransform.columns.3.z])
            let meshOriginToCamera = simd_length(meshWorldPos - cameraTranslation)
            // Subtract Mesh World BB From distance to camera
            let boundingRadius = length(vector_float3(meshModelBB.x, meshModelBB.y, meshModelBB.z))
            let edgeToCameraDistance = abs(meshOriginToCamera - boundingRadius)
            
            dictionary[index] = edgeToCameraDistance
        }
        
        // process dictionary
        var order: Int = 1
        var currentValue: Float = 0.0
        for (key, value) in dictionary.sorted(by: { $1.value < $0.value }) {
            meshes[key].renderingOrder = order
            if currentValue != value {
                order += 1
            }
            currentValue = value
        }
        
        meshes.sort(by: { $0.renderingOrder < $1.renderingOrder })
        updateTransformsBuffer()
    }
    
    func updateTransformsBuffer() {
        for index in 0..<meshes.count {
            let offset = MemoryLayout<matrix_float4x4>.size * index
            meshTransformsBuffer.contents().advanced(by: offset).storeBytes(of: meshes[index].transform, as: matrix_float4x4.self)
        }
    }
    
    func render(renderEncoder: MTLRenderCommandEncoder) {
        for meshIndex in 0..<meshes.count {
            let mtkMesh = meshes[meshIndex].mesh
            // Set mesh's vertex buffers
            for bufferIndex in 0..<mtkMesh.vertexBuffers.count {
                let vertexBuffer = mtkMesh.vertexBuffers[bufferIndex]
                renderEncoder.setVertexBuffer(vertexBuffer.buffer, offset: vertexBuffer.offset, index: bufferIndex)
            }
            
            renderEncoder.setVertexBuffer(meshTransformsBuffer, offset: MemoryLayout<matrix_float4x4>.size * meshIndex, index: Int(kBufferIndexMeshTransforms.rawValue))
            renderEncoder.setFragmentBuffer(meshTransformsBuffer, offset: MemoryLayout<matrix_float4x4>.size * meshIndex, index: Int(kBufferIndexMeshTransforms.rawValue))
            
            // Set diffuse texture
            renderEncoder.setFragmentTexture(meshes[meshIndex].baseColorTexture, index: Int(kTextureIndexColor.rawValue))
            renderEncoder.setFragmentSamplerState(meshes[meshIndex].baseColorTextureSampler!, index: Int(kTextureSamplerBaseColor.rawValue))
            
            // Set metallic texture
            renderEncoder.setFragmentTexture(meshes[meshIndex].metallnessTexture, index: Int(kTextureIndexMetallic.rawValue))
            renderEncoder.setFragmentSamplerState(meshes[meshIndex].metallnessTextureSampler, index: Int(kTextureSamplerMetallness.rawValue))
            
            // Set Roughness texture
            renderEncoder.setFragmentTexture(meshes[meshIndex].roughnessTexture, index: Int(kTextureIndexRoughness.rawValue))
            renderEncoder.setFragmentSamplerState(meshes[meshIndex].roughnessTextureSampler, index: Int(kTextureSamplerRoughness.rawValue))
            
            // Set Transparency Texture
            renderEncoder.setFragmentTexture(meshes[meshIndex].opacityTexture, index: Int(kTextureIndexTransparency.rawValue))
            renderEncoder.setFragmentSamplerState(meshes[meshIndex].opacityTextureSampler, index: Int(kTextureSamplerTransparency.rawValue))
            
            // Set Normal Texture
            renderEncoder.setFragmentTexture(meshes[meshIndex].normalTexture, index: Int(kTextureIndexNormal.rawValue))
            renderEncoder.setFragmentSamplerState(meshes[meshIndex].normalTextureSampler, index: Int(kTextureSamplerNormal.rawValue))
            
            // Set Ambient Occlusion Texture
            renderEncoder.setFragmentTexture(meshes[meshIndex].ambientOcclusionTexture, index: Int(kTextureIndexAmbientOcclusion.rawValue))
            renderEncoder.setFragmentSamplerState(meshes[meshIndex].ambientOcclusionSampler, index: Int(kTextureSamplerAmbientOcclusion.rawValue))
            
            // Set Emission Texture
            renderEncoder.setFragmentTexture(meshes[meshIndex].emissionTexture, index: Int(kTextureIndexEmission.rawValue))
            renderEncoder.setFragmentSamplerState(meshes[meshIndex].emissionSampler, index: Int(kTextureSamplerEmission.rawValue))
            
            // Draw each submesh of our mesh
            for submesh in mtkMesh.submeshes {
                renderEncoder.drawIndexedPrimitives(type: submesh.primitiveType,
                                                    indexCount: submesh.indexCount,
                                                    indexType: submesh.indexType,
                                                    indexBuffer: submesh.indexBuffer.buffer,
                                                    indexBufferOffset: submesh.indexBuffer.offset)
            }
        }
    }
}

/// Compute an index map from all elements of A.jointPaths to the corresponding paths in B.jointPaths
func mapJoints<A: JointPathRemappable>(from src: A, to dstJointPaths: [String]) -> [Int] {
    return src.jointPaths.compactMap { srcJointPath in
        if let index = dstJointPaths.firstIndex(of: srcJointPath) {
            return index
        }
        print("Warning! animated joint \(srcJointPath) does not exist in skeleton")
        return nil
    }
}

protocol JointPathRemappable {
    var jointPaths: [String] { get }
}

extension MDLPackedJointAnimation: JointPathRemappable {}

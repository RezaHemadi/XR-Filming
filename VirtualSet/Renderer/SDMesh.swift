//
//  SDMesh.swift
//  VirtualSet
//
//  Created by Reza on 9/22/21.
//

import Foundation
import MetalKit
import os.signpost

/// - TAG: SDMesh
class SDMesh {
    // MARK: - Properties
    let mesh: MTKMesh
    
    // Model Space Transform
    let transform: matrix_float4x4
    
    let boundingBox: vector_float3
    
    // Material
    var baseColorTexture: MTLTexture?
    var baseColorTextureSampler: MTLSamplerState?
    var baseColorRGB: vector_float3 = [0, 0, 0]
    
    // Metalness
    var metallnessTexture: MTLTexture?
    var metallnessTextureSampler: MTLSamplerState?
    
    // Roughness
    var roughnessTexture: MTLTexture?
    var roughnessTextureSampler: MTLSamplerState?
    
    // Opacity
    var opacityTexture: MTLTexture?
    var opacityTextureSampler: MTLSamplerState?
    
    // Normal Texture
    var normalTexture: MTLTexture?
    var normalTextureSampler: MTLSamplerState?
    
    // Ambient Occlusion Texture
    var ambientOcclusionTexture: MTLTexture?
    var ambientOcclusionSampler: MTLSamplerState?
    
    // Emission Texture
    var emissionTexture: MTLTexture?
    var emissionSampler: MTLSamplerState?
    
    var renderingOrder: Int = 0
    
    // Specifies whether the mesh is completely opaque
    var isOpaque: Bool = true
    
    // MARK: - Initialization
    init(mesh: MTKMesh, transform: matrix_float4x4, boundingBox: vector_float3) {
        self.mesh = mesh
        self.transform = transform
        self.boundingBox = boundingBox
        
        
        let upperLeft = transform.upper_left3x3()
        let determinent = upperLeft.determinant
        if determinent.isLess(than: 0.0) {
            reverseWindingOrder()
        }
    }
    
    // MARK: - Methods
    func reverseWindingOrder() {
        for submesh in mesh.submeshes {
            let indexType = submesh.indexType
            let buffer = submesh.indexBuffer
            let indexCount = submesh.indexCount
            
            switch indexType {
            case .uint16:
                var originalIndices = [UInt16]()
                for i in 0..<indexCount {
                    let bufferAddress = buffer.buffer.contents().advanced(by: MemoryLayout<UInt16>.size * i).assumingMemoryBound(to: UInt16.self)
                    let originalContents = bufferAddress.pointee
                    originalIndices.append(originalContents)
                }
                originalIndices.reverse()
                // Copy Original indices back to buffer in reverse order
                for i in 0..<indexCount {
                    let bufferAddress = buffer.buffer.contents().advanced(by: MemoryLayout<UInt16>.size * i).assumingMemoryBound(to: UInt16.self)
                    bufferAddress.pointee = originalIndices[i]
                }
            case .uint32:
                var originalIndices = [UInt32]()
                for i in 0..<indexCount {
                    let bufferAddress = buffer.buffer.contents().advanced(by: MemoryLayout<UInt32>.size * i).assumingMemoryBound(to: UInt32.self)
                    let originalContents = bufferAddress.pointee
                    originalIndices.append(originalContents)
                }
                originalIndices.reverse()
                // Copy Original indices back to buffer in reverse order
                for i in 0..<indexCount {
                    let bufferAddress = buffer.buffer.contents().advanced(by: MemoryLayout<UInt32>.size * i).assumingMemoryBound(to: UInt32.self)
                    bufferAddress.pointee = originalIndices[i]
                }
            @unknown default:
                fatalError()
            }
        }
    }
    
    func configureSpecularMaterial(properties: [MDLMaterialProperty], device: MTLDevice) {
        
    }
    
    func configureSpecularExponentMaterial(properties: [MDLMaterialProperty], device: MTLDevice) {
        
    }
    
    func configureSpecularTintMaterial(properties: [MDLMaterialProperty], device: MTLDevice) {
        
    }
    
    func configureAnisotropicMaterial(properties: [MDLMaterialProperty], device: MTLDevice) {
        
    }
    
    func configureSheenProperties(properties: [MDLMaterialProperty], device: MTLDevice) {
        
    }
    
    func configureSheenTintProperties(properties: [MDLMaterialProperty], device: MTLDevice) {
        
    }
    
    func configureClearCoatProperties(properties: [MDLMaterialProperty], device: MTLDevice) {
        
    }
    
    func configureCoatGloassProperties(properties: [MDLMaterialProperty], device: MTLDevice) {
        
    }
    
    func configureBumpProperties(properties: [MDLMaterialProperty], device: MTLDevice) {
        
    }
    
    func configureInterfaceIndexOfRefraction(properties: [MDLMaterialProperty], device: MTLDevice) {
        
    }
    
    func configureObjectSpaceNormalProperties(properties: [MDLMaterialProperty], device: MTLDevice) {
        
    }
    
    func configureDisplacementMaterial(properties: [MDLMaterialProperty], device: MTLDevice) {
        
    }
    
    func configureDisplacementScaleMaterial(properties: [MDLMaterialProperty], device: MTLDevice) {
        
    }
    
    func configureEmissionMaterial(properties: [MDLMaterialProperty], device: MTLDevice) {
        os_log(.info, "mesh %s has %s emission properties", "\(mesh.name)", "\(properties.count)")
        for property in properties {
            switch property.type {
            case .texture:
                if let sampler = property.textureSamplerValue {
                    let pair = makeTextureFromMDLSampler(sampler, device: device)
                    emissionTexture = pair.texture
                    emissionSampler = pair.sampler
                }
            case .float3:
                guard emissionTexture == nil else { return }
                
                let texture = makeUniformTexture(colorValues: property.float3Value, device: device)
                emissionTexture = texture
                
                let samplerDescriptor = MTLSamplerDescriptor()
                samplerDescriptor.sAddressMode = .repeat
                samplerDescriptor.tAddressMode = .repeat
                emissionSampler = device.makeSamplerState(descriptor: samplerDescriptor)
            default:
                break
            }
        }
    }
    
    func configureAmbientOcclusionMaterial(properties: [MDLMaterialProperty], device: MTLDevice) {
        guard properties.count != 0 else {
            // Create Default Opaque Transparency Texture
            // Create Uniform Texture
            let texture = makeUniformTexture(colorValues: [1.0, 1.0, 1.0], device: device)
            ambientOcclusionTexture = texture
            
            // Create Sampler
            let samplerDescriptor = MTLSamplerDescriptor()
            samplerDescriptor.sAddressMode = .repeat
            samplerDescriptor.tAddressMode = .repeat
            ambientOcclusionSampler = device.makeSamplerState(descriptor: samplerDescriptor)
            
            return
        }
        // Ambient Occlusion Properties are either texture or float
        for property in properties {
            switch property.type {
            case .texture:
                if let sampler = property.textureSamplerValue {
                    let pair = makeTextureFromMDLSampler(sampler, device: device)
                    ambientOcclusionTexture = pair.texture
                    ambientOcclusionSampler = pair.sampler
                }
            case .float:
                /// Make sure texture is not inialized with image texture
                guard ambientOcclusionTexture == nil else { return }
                
                let texture = makeUniformTexture(colorValues: [1.0, 1.0, 1.0], device: device)
                ambientOcclusionTexture = texture
                
                let samplerDescriptor = MTLSamplerDescriptor()
                samplerDescriptor.sAddressMode = .repeat
                samplerDescriptor.tAddressMode = .repeat
                ambientOcclusionSampler = device.makeSamplerState(descriptor: samplerDescriptor)!
                
            default:
                break
            }
        }
    }
    
    func configureAmbientOcclusionScaleMaterial(properties: [MDLMaterialProperty], device: MTLDevice) {
        
    }
    
    func configureTangentSpaceNormal(properties: [MDLMaterialProperty], device: MTLDevice) {
        guard properties.count != 0 else {
            // Create Default Opaque Transparency Texture
            // Create Uniform Texture
            let texture = makeUniformTexture(colorValues: [0.5, 0.5, 1.0], device: device)
            normalTexture = texture
            
            // Create Sampler
            let samplerDescriptor = MTLSamplerDescriptor()
            samplerDescriptor.sAddressMode = .repeat
            samplerDescriptor.tAddressMode = .repeat
            normalTextureSampler = device.makeSamplerState(descriptor: samplerDescriptor)
            
            return
        }
        for property in properties {
            switch property.type {
            case .texture:
                if let sampler = property.textureSamplerValue {
                    let pair = makeTextureFromMDLSampler(sampler, device: device)
                    normalTexture = pair.texture
                    normalTextureSampler = pair.sampler
                }
            case .float3:
                guard normalTexture == nil else { return}
                
                let texture = makeUniformTexture(colorValues: [0.5, 0.5, property.float3Value.z], device: device)
                normalTexture = texture
                // Create Sampler
                let samplerDescriptor = MTLSamplerDescriptor()
                samplerDescriptor.sAddressMode = .repeat
                samplerDescriptor.tAddressMode = .repeat
                normalTextureSampler = device.makeSamplerState(descriptor: samplerDescriptor)
                
            default:
                break
            }
        }
    }
    func configureOpacity(properties: [MDLMaterialProperty], device: MTLDevice) {
        guard properties.count != 0 else {
            // Create Default Opaque Transparency Texture
            // Create Uniform Texture
            let texture = makeUniformTexture(colorValues: [1.0, 1.0, 1.0], device: device)
            opacityTexture = texture
            
            // Create Sampler
            let samplerDescriptor = MTLSamplerDescriptor()
            samplerDescriptor.sAddressMode = .repeat
            samplerDescriptor.tAddressMode = .repeat
            opacityTextureSampler = device.makeSamplerState(descriptor: samplerDescriptor)
            
            return
        }
        /// Opacity Properties are either in texture format or float format
        for property in properties {
            switch property.type {
            case .texture:
                if let sampler = property.textureSamplerValue {
                    let pair = makeTextureFromMDLSampler(sampler, device: device)
                    opacityTexture = pair.texture
                    opacityTextureSampler = pair.sampler
                    isOpaque = false
                }
            case .float:
                // Make Sure No Texture Is Created From MDLTexture Image
                guard opacityTexture == nil else { return }
                // Create Uniform Texture
                let texture = makeUniformTexture(colorValues: [property.floatValue, property.floatValue, property.floatValue], device: device)
                opacityTexture = texture
                
                // Create Sampler
                let samplerDescriptor = MTLSamplerDescriptor()
                samplerDescriptor.sAddressMode = .repeat
                samplerDescriptor.tAddressMode = .repeat
                opacityTextureSampler = device.makeSamplerState(descriptor: samplerDescriptor)
                
                if property.floatValue.isLess(than: 1.0) {
                    isOpaque = false
                }
                
            default:
                break
            }
        }
    }
    func configureRoughness(properties: [MDLMaterialProperty], device: MTLDevice) {
        /// Roughness is either texture or a float value
        for property in properties {
            switch property.type {
            case .texture:
                if let sampler = property.textureSamplerValue {
                    let pair = makeTextureFromMDLSampler(sampler, device: device)
                    roughnessTexture = pair.texture
                    roughnessTextureSampler = pair.sampler
                }
            case .float:
                /// Make sure texture is not inialized with image texture
                guard roughnessTexture == nil else { return }
                let texture = makeUniformTexture(colorValues: [property.floatValue, property.floatValue, property.floatValue], device: device)
                roughnessTexture = texture
                
                let samplerDescriptor = MTLSamplerDescriptor()
                samplerDescriptor.sAddressMode = .repeat
                samplerDescriptor.tAddressMode = .repeat
                roughnessTextureSampler = device.makeSamplerState(descriptor: samplerDescriptor)!
                
            default:
                break
            }
        }
    }
    func configureBaseColor(properties: [MDLMaterialProperty], device: MTLDevice) {
        for baseColorProperty in properties {
            switch baseColorProperty.type {
            case .none:
                break
            case .string:
                break
            case .URL:
                break
            case .texture:
                if let sampler = baseColorProperty.textureSamplerValue {
                    let pair = makeTextureFromMDLSampler(sampler, device: device)
                    baseColorTexture = pair.texture
                    baseColorTextureSampler = pair.sampler
                }
                break
            case .color:
                break
            case .float:
                break
            case .float2:
                break
            case .float3:
                // Skip If Mesh has Image Texture associated with it
                guard baseColorTexture == nil else { return }
                
                // Create A Uniform Color Texture Based on the float3 color value
                let rgbValue = baseColorProperty.float3Value
                let texture = makeUniformTexture(colorValues: rgbValue, device: device)
                baseColorTexture = texture
                
                let samplerDescriptor = MTLSamplerDescriptor()
                samplerDescriptor.sAddressMode = .repeat
                samplerDescriptor.tAddressMode = .repeat
                baseColorTextureSampler = device.makeSamplerState(descriptor: samplerDescriptor)!
                
                break
            case .float4:
                break
            case .matrix44:
                break
            case .buffer:
                break
            @unknown default:
                break
            }
            
        }
    }
    
    func configureMetallicProperty(properties: [MDLMaterialProperty], device: MTLDevice) {
        for property in properties {
            switch property.type {
            case .texture:
                // configure texture
                if let sampler = property.textureSamplerValue {
                    let pair = makeTextureFromMDLSampler(sampler, device: device)
                    metallnessTexture = pair.texture
                    metallnessTextureSampler = pair.sampler
                }
            case .float:
                // configure with float value
                // check if metallness texture is not initialized
                guard metallnessTexture == nil else { return }
                
                // Create A Uniform Color Texture Based on the float3 color value
                let rgbValue = property.floatValue
                let texture = makeUniformTexture(colorValues: [rgbValue, rgbValue, rgbValue], device: device)
                metallnessTexture = texture
                
                let samplerDescriptor = MTLSamplerDescriptor()
                samplerDescriptor.sAddressMode = .repeat
                samplerDescriptor.tAddressMode = .repeat
                metallnessTextureSampler = device.makeSamplerState(descriptor: samplerDescriptor)!
            default:
                // never happens
                break
            }
        }
    }
    
    // MARK: - Helper Methods
    private func makeTextureFromMDLSampler(_ sampler: MDLTextureSampler, device: MTLDevice) -> (sampler: MTLSamplerState, texture: MTLTexture) {
        let mdlTexture = sampler.texture!
        
        let loader = MTKTextureLoader(device: device)
        let texture = try! loader.newTexture(texture: mdlTexture, options: nil)
        
        let mtkSamplerDescriptor = MTLSamplerDescriptor()
        mtkSamplerDescriptor.minFilter = .nearest
        mtkSamplerDescriptor.magFilter = .linear
        
        if let hardwareFilter = sampler.hardwareFilter {
            mtkSamplerDescriptor.sAddressMode = (hardwareFilter.sWrapMode == .clamp ? .clampToEdge :
                                                    hardwareFilter.sWrapMode == .mirror ? .mirrorClampToEdge :
                                                    .repeat)
            mtkSamplerDescriptor.tAddressMode = (hardwareFilter.tWrapMode == .clamp ? .clampToEdge :
                                                    hardwareFilter.tWrapMode == .mirror ? .mirrorClampToEdge :
                                                    .repeat)
        }
        let mtkSampler = device.makeSamplerState(descriptor: mtkSamplerDescriptor)
        
        return (sampler: mtkSampler!, texture: texture)
    }
    
    private func makeUniformTexture(colorValues: vector_float3, device: MTLDevice) -> MTLTexture {
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.height = 8
        textureDescriptor.width = 8
        textureDescriptor.pixelFormat = .rgba8Unorm
        textureDescriptor.mipmapLevelCount = 1
        textureDescriptor.storageMode = .shared
        textureDescriptor.arrayLength = 1
        textureDescriptor.sampleCount = 1
        textureDescriptor.cpuCacheMode = .writeCombined
        textureDescriptor.textureType = .type2D
        textureDescriptor.usage = .shaderRead
        let texture = device.makeTexture(descriptor: textureDescriptor)!
        let origin = MTLOrigin(x: 0, y: 0, z: 0)
                let size = MTLSize(width: texture.width, height: texture.height, depth: texture.depth)
                let region = MTLRegion(origin: origin, size: size)
        let mappedColor = simd_uchar4(simd_float4(colorValues, colorValues.x) * 255)
                Array<simd_uchar4>(repeating: mappedColor, count: 64).withUnsafeBytes { ptr in
                    texture.replace(region: region, mipmapLevel: 0, withBytes: ptr.baseAddress!, bytesPerRow: 32)
                }
        return texture
    }
 }

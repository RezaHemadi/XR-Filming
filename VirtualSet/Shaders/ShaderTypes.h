//
//  ShaderTypes.h
//  VirtualSet
//
//  Created by Reza on 9/21/21.
//

#ifndef ShaderTypes_h
#define ShaderTypes_h

#include <simd/simd.h>

// Buffer index values shared between shader and C code to ensure Metal shader buffer inputs match
//   Metal API buffer set calls
typedef enum BufferIndices {
    kBufferIndexMeshPositions = 0,
    kBufferIndexMeshGenerics     = 1,
    kBufferIndexInstanceUniforms = 2,
    kBufferIndexSharedUniforms   = 3,
    kBufferIndexMeshTransforms = 4,
    kBufferIndexRGBcolor = 5,
    kBufferIndexPalette = 6
} BufferIndices;

// Texture index values shared between shader and C code to ensure Metal shader texture indices
//   match indices of Metal API texture set calls
typedef enum TextureIndices {
    kTextureIndexColor    = 0,
    kTextureIndexY        = 1,
    kTextureIndexCbCr     = 2,
    kTextureIndexMetallic = 3,
    kTextureIndexRoughness = 4,
    kTextureIndexTransparency = 5,
    kTextureIndexNormal = 6,
    kTextureIndexAmbientOcclusion = 7,
    kTextureIndexEmission = 8,
} TextureIndices;

// Attribute index values shared between shader and C code to ensure Metal shader vertex
//   attribute indices match the Metal API vertex descriptor attribute indices
typedef enum VertexAttributes {
    kVertexAttributePosition  = 0,
    kVertexAttributeTexcoord  = 1,
    kVertexAttributeNormal    = 2,
    kVertexAttributeTangent   = 3,
    kVertexAttributeBiTangent = 4,
    kVertexAttributeAO = 5,
    kVertexAttributeJointIndices = 6,
    kVertexAttributeJointWeights = 7
} VertexAttributes;

typedef enum TextureSamplerIndices {
    kTextureSamplerBaseColor = 0,
    kTextureSamplerMetallness = 1,
    kTextureSamplerRoughness = 2,
    kTextureSamplerTransparency = 3,
    kTextureSamplerNormal = 4,
    kTextureSamplerAmbientOcclusion = 5,
    kTextureSamplerEmission = 6,
} TextureSamplerIndices;

// Structure shared between shader and C code to ensure the layout of shared uniform data accessed in
//    Metal shaders matches the layout of uniform data set in C code
typedef struct {
    // Camera Uniforms
    matrix_float4x4 cameraTransform;
    matrix_float4x4 projectionMatrix;
    matrix_float4x4 viewMatrix;
    
    // Lighting Properties
    vector_float3 ambientLightColor;
    vector_float3 directionalLightDirection;
    vector_float3 directionalLightColor;
    float materialShininess;
    
    // Matting
    int useDepth;
} SharedUniforms;

// Structure shared between shader and C code to ensure the layout of instance uniform data accessed in
//    Metal shaders matches the layout of uniform data set in C code
typedef struct {
    matrix_float4x4 modelMatrix;
} InstanceUniforms;

#endif /* ShaderTypes_h */


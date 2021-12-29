//
//  Shaders.metal
//  VirtualSet
//
//  Created by Reza on 9/21/21.
//

#include <metal_stdlib>

#include <simd/simd.h>

// Include header shared between this Metal shader code and C code executing Metal API commands
#import "ShaderTypes.h"

using namespace metal;

// Convert from YCbCr to rgb
float4 ycbcrToRGBTransform(float4 y, float4 CbCr) {
    const float4x4 ycbcrToRGBTransform = float4x4(
      float4(+1.0000f, +1.0000f, +1.0000f, +0.0000f),
      float4(+0.0000f, -0.3441f, +1.7720f, +0.0000f),
      float4(+1.4020f, -0.7141f, +0.0000f, +0.0000f),
      float4(-0.7010f, +0.5291f, -0.8860f, +1.0000f)
    );

    float4 ycbcr = float4(y.r, CbCr.rg, 1.0);
    return ycbcrToRGBTransform * ycbcr;
}

typedef struct {
    float2 position [[attribute(kVertexAttributePosition)]];
    float2 texCoord [[attribute(kVertexAttributeTexcoord)]];
} ImageVertex;


typedef struct {
    float4 position [[position]];
    float2 texCoord;
} ImageColorInOut;


// Captured image vertex function
vertex ImageColorInOut capturedImageVertexTransform(ImageVertex in [[stage_in]]) {
    ImageColorInOut out;
    
    // Pass through the image vertex's position
    out.position = float4(in.position, 0.0, 1.0);
    
    // Pass through the texture coordinate
    out.texCoord = in.texCoord;
    
    return out;
}

// Captured image fragment function
fragment float4 capturedImageFragmentShader(ImageColorInOut in [[stage_in]],
                                            texture2d<float, access::sample> capturedImageTextureY [[ texture(kTextureIndexY) ]],
                                            texture2d<float, access::sample> capturedImageTextureCbCr [[ texture(kTextureIndexCbCr) ]]) {
    
    constexpr sampler colorSampler(mip_filter::linear,
                                   mag_filter::linear,
                                   min_filter::linear);
    
    const float4x4 ycbcrToRGBTransform = float4x4(
        float4(+1.0000f, +1.0000f, +1.0000f, +0.0000f),
        float4(+0.0000f, -0.3441f, +1.7720f, +0.0000f),
        float4(+1.4020f, -0.7141f, +0.0000f, +0.0000f),
        float4(-0.7010f, +0.5291f, -0.8860f, +1.0000f)
    );
    
    // Sample Y and CbCr textures to get the YCbCr color at the given texture coordinate
    float4 ycbcr = float4(capturedImageTextureY.sample(colorSampler, in.texCoord).r,
                          capturedImageTextureCbCr.sample(colorSampler, in.texCoord).rg, 1.0);
    
    // Return converted RGB color
    return ycbcrToRGBTransform * ycbcr;
}


typedef struct {
    float3 position [[attribute(kVertexAttributePosition)]];
    float2 texCoord [[attribute(kVertexAttributeTexcoord)]];
    half3 normal    [[attribute(kVertexAttributeNormal)]];
    float3 tangent [[attribute(kVertexAttributeTangent)]];
    float3 bitangent [[attribute(kVertexAttributeBiTangent)]];
    float occlusion [[attribute(kVertexAttributeAO)]];
    ushort4 jointIds [[attribute(kVertexAttributeJointIndices)]];
    float4 jointWeights [[attribute(kVertexAttributeJointWeights)]];
} Vertex;


typedef struct {
    float4 position [[position]];
    float2 texcoord;
    float4 color;
    half3  eyePosition;
    float3 fragWorldPos;
    float3 T;
    float3 B;
    float3 N;
    float occlusion;
} ColorInOut;

// Geometry vertex shader
vertex ColorInOut geometryVertexShader(Vertex in [[stage_in]],
                                       constant SharedUniforms &sharedUniforms [[ buffer(kBufferIndexSharedUniforms) ]],
                                       constant InstanceUniforms &instanceUniforms [[ buffer(kBufferIndexInstanceUniforms) ]],
                                       constant matrix_float4x4 &meshTransform [[ buffer(kBufferIndexMeshTransforms) ]],
                                       constant matrix_float4x4 *palette [[ buffer(kBufferIndexPalette) ]])
{
    ColorInOut out;
    
    // Make position a float4 to perform 4x4 matrix math on it.
    float4 position = float4(in.position, 1.0);
    
    ushort4 jIdx = in.jointIds;
    float4 w = in.jointWeights;
    float4 skinnedPosition = w[0] * (palette[jIdx[0]] * position) +
                             w[1] * (palette[jIdx[1]] * position) +
                             w[2] * (palette[jIdx[2]] * position) +
                             w[3] * (palette[jIdx[3]] * position);
    
    float4x4 modelMatrix = instanceUniforms.modelMatrix;
    float4x4 modelViewMatrix = sharedUniforms.viewMatrix * modelMatrix;
    
    // Calculate the position of our vertex in clip space and output for clipping and rasterization
    out.position = sharedUniforms.projectionMatrix * modelViewMatrix * meshTransform * position;
    
    // Calculate the position of our vertex in eye space
    out.eyePosition = half3((modelViewMatrix * position).xyz);
    
    
    // Configure Construct T, B, N for normal mapping
    /// in.normal is in each mesh's local coordinate space
    /// in.normal needs to be transformed with mesh transform to be in model coordinate space
    float4 localSpaceNormal = float4(float3(in.normal), 0); // This Normal is in Mesh Local Space
    float4 modelSpaceNormal = normalize(meshTransform * localSpaceNormal); // This Normal is in Model Coordinate Space
    /// Tangents and Bitangents also need to be transformed by the mesh transform to output to fragment shader
    float4 localSpaceTangent = float4(in.tangent, 0); // Tangents are vectors so the w component must be 0
    float4 modelSpaceTangent = normalize(meshTransform * localSpaceTangent); // This Tangent is in model Local Space
    
    out.T = modelSpaceTangent.xyz;
    out.N = modelSpaceNormal.xyz;
    out.B = cross(modelSpaceTangent.xyz, modelSpaceNormal.xyz);
    
    out.texcoord = float2(in.texCoord.x, in.texCoord.y);
    out.fragWorldPos = (modelMatrix * position).xyz;
    
    out.occlusion = in.occlusion != 0.0 ? in.occlusion : 1.0;
    
    return out;
};

// Geometry Fragment Shader
fragment float4 geometryFragmentShader(ColorInOut in [[stage_in]],
                                       constant SharedUniforms &uniforms [[ buffer(kBufferIndexSharedUniforms) ]],
                                       constant InstanceUniforms &instanceUniforms [[ buffer(kBufferIndexInstanceUniforms) ]],
                                       constant matrix_float4x4 &meshTransform [[ buffer(kBufferIndexMeshTransforms) ]],
                                       texture2d<float, access::sample> diffuseTexture [[ texture(kTextureIndexColor) ]],
                                       sampler baseColorSampler [[ sampler(kTextureSamplerBaseColor) ]],
                                       texture2d<float, access::sample> metallicTexture [[ texture(kTextureIndexMetallic) ]],
                                       sampler metallnessSampler [[ sampler(kTextureSamplerMetallness) ]],
                                       texture2d<float, access::sample> roughnessTexture [[ texture(kTextureIndexRoughness) ]],
                                       sampler roughnessSampler [[ sampler(kTextureSamplerRoughness) ]],
                                       texture2d<float, access:: sample> transparencyTexture [[ texture(kTextureIndexTransparency) ]],
                                       sampler transparencySampler [[ sampler(kTextureSamplerTransparency) ]],
                                       texture2d<float, access:: sample> normalTexture [[ texture(kTextureIndexNormal) ]],
                                       sampler normalSampler [[ sampler(kTextureSamplerNormal) ]],
                                       texture2d<float, access:: sample> ambientOcclusionTexture [[ texture(kTextureIndexAmbientOcclusion) ]],
                                       sampler ambientOcclusionSampler [[ sampler(kTextureSamplerAmbientOcclusion) ]],
                                       texture2d<float, access:: sample> emissionTexture [[ texture(kTextureIndexEmission) ]],
                                       sampler emissionSampler [[ sampler(kTextureSamplerEmission) ]])
{
    // Processing Emission
    float4 emissionVector = emissionTexture.sample(emissionSampler, in.texcoord);
    if (emissionVector.r  != 0.0) {
        return float4(emissionVector.rgb, 1.0);
    }
    
    /// Calculating The Specular Component
    float3 cameraPos = vector_float3(uniforms.cameraTransform.columns[3].x, uniforms.cameraTransform.columns[3].y, uniforms.cameraTransform.columns[3].z);
    float3 lightDirection = uniforms.directionalLightDirection; // For Other Types of Light must be normalize(lightPos - FragPos)
    float3 viewDirectioin = normalize(cameraPos - in.fragWorldPos);
    float3 halfwayDir = normalize(lightDirection + viewDirectioin);
    
    float4 normalMap = normalTexture.sample(normalSampler, in.texcoord);
    float3 tangent_normal = normalize((normalMap * 2.0) - 1.0).xyz;
    matrix_float3x3 TBN = float3x3(in.T, in.B, in.N);
    float3 modelSpaceNormal = normalize(TBN * tangent_normal);
    float4 worldSpaceNormal = normalize(instanceUniforms.modelMatrix * float4(modelSpaceNormal, 0));
    
    // Roughness Map Testing
    float4 roughnessSample = roughnessTexture.sample(roughnessSampler, in.texcoord);
    float roughnessValue = roughnessSample.r;
    float shininess = 1.0 - (roughnessValue);
    
    // Diffuse Term
    float diffuseAmt = max(0.0, dot(uniforms.directionalLightDirection, worldSpaceNormal.xyz));
    float4 meshCol = diffuseTexture.sample(baseColorSampler, in.texcoord);
    float3 diffuseColor = meshCol.xyz * uniforms.directionalLightColor * diffuseAmt;
    
    // Ambient
    float4 ambientOcclusionFactor = ambientOcclusionTexture.sample(ambientOcclusionSampler, in.texcoord) * pow(in.occlusion, 2);
    float3 ambCol = uniforms.ambientLightColor;
    float3 ambient = ambCol * meshCol.xyz * pow(ambientOcclusionFactor.r, 2);
    
    // Specular Term
    float spec = pow(max(dot(worldSpaceNormal.xyz, halfwayDir), 0.0), shininess * 50);
    float3 specular = uniforms.directionalLightColor * 0.5 * spec;
    
    float4 transparency = transparencyTexture.sample(transparencySampler, in.texcoord);
    
    
    return float4(diffuseColor + ambient + specular, transparency.w);
    
};

typedef struct {
    float2 position;
    float2 texCoord;
} CompositeVertex;

typedef struct {
    float4 position [[position]];
    float2 texCoordCamera;
    float2 texCoordScene;
} CompositeColorInOut;

// Composite the image vertex function.
vertex CompositeColorInOut compositeImageVertexTransform(const device CompositeVertex* cameraVertices [[ buffer(0) ]],
                                                         const device CompositeVertex* sceneVertices [[ buffer(1) ]],
                                                         unsigned int vid [[ vertex_id ]]) {
    CompositeColorInOut out;

    const device CompositeVertex& cv = cameraVertices[vid];
    const device CompositeVertex& sv = sceneVertices[vid];

    out.position = float4(cv.position, 0.0, 1.0);
    out.texCoordCamera = cv.texCoord;
    out.texCoordScene = sv.texCoord;

    return out;
}


// Composite the image fragment function.
fragment half4 compositeImageFragmentShader(CompositeColorInOut in [[ stage_in ]],
                                    texture2d<float, access::sample> capturedImageTextureY [[ texture(0) ]],
                                    texture2d<float, access::sample> capturedImageTextureCbCr [[ texture(1) ]],
                                    texture2d<float, access::sample> sceneColorTexture [[ texture(2) ]],
                                    depth2d<float, access::sample> sceneDepthTexture [[ texture(3) ]],
                                    texture2d<float, access::sample> alphaTexture [[ texture(4) ]],
                                    texture2d<float, access::sample> dilatedDepthTexture [[ texture(5) ]],
                                    constant SharedUniforms &uniforms [[ buffer(kBufferIndexSharedUniforms) ]])
{
    constexpr sampler s(address::clamp_to_edge, filter::linear);

    float2 cameraTexCoord = in.texCoordCamera;
    float2 sceneTexCoord = in.texCoordScene;

    // Sample Y and CbCr textures to get the YCbCr color at the given texture coordinate.
    float4 rgb = ycbcrToRGBTransform(capturedImageTextureY.sample(s, cameraTexCoord), capturedImageTextureCbCr.sample(s, cameraTexCoord));

    // Perform composition with the matting.
    half4 sceneColor = half4(sceneColorTexture.sample(s, sceneTexCoord));
    float sceneDepth = sceneDepthTexture.sample(s, sceneTexCoord);

    half4 cameraColor = half4(rgb);
    half alpha = half(alphaTexture.sample(s, cameraTexCoord).r);

    half showOccluder = 1.0;

    if (uniforms.useDepth) {
        float dilatedLinearDepth = half(dilatedDepthTexture.sample(s, cameraTexCoord).r);

        // Project linear depth with the projection matrix.
        float dilatedDepth = clamp((uniforms.projectionMatrix[2][2] * -dilatedLinearDepth + uniforms.projectionMatrix[3][2]) / (uniforms.projectionMatrix[2][3] * -dilatedLinearDepth + uniforms.projectionMatrix[3][3]), 0.0, 1.0);

        showOccluder = (half)step(dilatedDepth, sceneDepth); // forwardZ case
    }


    half4 occluderResult = mix(sceneColor, cameraColor, alpha);
    half4 mattingResult = mix(sceneColor, occluderResult, showOccluder);
    return mattingResult;
}




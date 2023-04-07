//
//  MathUtilities.swift
//  VirtualSet
//
//  Created by Reza on 9/23/21.
//

import Foundation
import simd

func matrix_float4x4_translation(translationX: Float, translationY: Float, translationZ: Float) -> matrix_float4x4 {
    return matrix_float4x4(columns: (vector_float4(1.0, 0.0, 0.0, 0.0),
                                     vector_float4(0.0, 1.0, 0.0, 0.0),
                                     vector_float4(0.0, 0.0, 1.0, 0.0),
                                     vector_float4(translationX, translationY, translationZ, 1.0)))
    
}

func matrix_float3x3_translation(translationX: Float, translationY: Float) -> matrix_float3x3 {
    return matrix_float3x3(columns: (vector_float3(1.0, 0.0, 0.0),
                                     vector_float3(0.0, 1.0, 0.0),
                                     vector_float3(translationX, translationY, 1.0)))
}

/// A trasformation that rotates about the origin
func matrix_float3x3_rotation(radians: Float) -> matrix_float3x3 {
    return matrix_float3x3(columns: ([cos(radians), sin(radians), 0.0],
                                     [-sin(radians), cos(radians), 0.0],
                                     [0.0, 0.0, 1.0]))
}

func matrix_perspective_right_hand(fovyRadians fovy: Float, aspectRatio: Float, nearZ: Float, farZ: Float) -> matrix_float4x4 {
    let ys = 1 / tanf(fovy * 0.5)
    let xs = ys / aspectRatio
    let zs = farZ / (nearZ - farZ)
    return matrix_float4x4.init(columns:(vector_float4(xs,  0, 0,   0),
                                         vector_float4( 0, ys, 0,   0),
                                         vector_float4( 0,  0, zs, -1),
                                         vector_float4( 0,  0, zs * nearZ, 0)))
}
func radians_from_degrees(_ degrees: Float) -> Float {
    return (degrees / 180) * .pi
}
func degrees_from_radians(_ radians: Float) -> Float {
    return radians * (180 / (2 * .pi))
}
func matrix4x4_rotation(radians: Float, axis: SIMD3<Float>) -> matrix_float4x4 {
    let unitAxis = normalize(axis)
    let ct = cosf(radians)
    let st = sinf(radians)
    let ci = 1 - ct
    let x = unitAxis.x, y = unitAxis.y, z = unitAxis.z
    return matrix_float4x4.init(columns:(vector_float4(    ct + x * x * ci, y * x * ci + z * st, z * x * ci - y * st, 0),
                                         vector_float4(x * y * ci - z * st,     ct + y * y * ci, z * y * ci + x * st, 0),
                                         vector_float4(x * z * ci + y * st, y * z * ci - x * st,     ct + z * z * ci, 0),
                                         vector_float4(                  0,                   0,                   0, 1)))
}
func matrix4x4_scale(scaleX: Float, scaleY: Float, scaleZ: Float) -> matrix_float4x4 {
    return matrix_float4x4(columns: (vector_float4(scaleX, 0.0, 0.0, 0.0),
                                     vector_float4(0.0, scaleY, 0.0, 0.0),
                                     vector_float4(0.0, 0.0, scaleZ, 0.0),
                                     vector_float4(0.0, 0.0, 0.0, 1.0)))
}

func matrix4x4_rotation(yaw: Float) -> matrix_float4x4 {
    let col0 = simd_float4([cos(yaw), 0, -sin(yaw), 0])
    let col1 = simd_float4([0.0, 1.0, 0.0, 0.0])
    let col2 = simd_float4([sin(yaw), 0.0, cos(yaw), 0.0])
    let col3 = simd_float4([0.0, 0.0, 0.0, 1.0])
    
    return matrix_float4x4(columns: (col0, col1, col2, col3))
}

func matrix4x4_rotation(pitch: Float) -> matrix_float4x4 {
    let col0 = simd_float4([1.0, 0.0, 0.0, 0.0])
    let col1 = simd_float4([0.0, cos(pitch), sin(pitch), 0.0])
    let col2 = simd_float4([0.0, -sin(pitch), cos(pitch), 0.0])
    let col3 = simd_float4([0.0, 0.0, 0.0, 1.0])
    
    return matrix_float4x4(columns: (col0, col1, col2, col3))
}

func matrix4x4_rotation(roll: Float) -> matrix_float4x4 {
    let col0 = simd_float4([cos(roll), sin(roll), 0.0, 0.0])
    let col1 = simd_float4([-sin(roll), cos(roll), 0.0, 0.0])
    let col2 = simd_float4([0.0, 0.0, 1.0, 0.0])
    let col3 = simd_float4([0.0, 0.0, 0.0, 1.0])
    
    return matrix_float4x4(columns: (col0, col1, col2, col3))
}

extension simd_float4x4 {
    func upper_left3x3() -> simd_float3x3 {
        let column1: SIMD3<Float> = [columns.0.x, columns.0.y, columns.0.z]
        let column2: SIMD3<Float> = [columns.1.x, columns.1.y, columns.1.z]
        let column3: SIMD3<Float> = [columns.2.x, columns.2.y, columns.2.z]
        
        return simd_float3x3([column1, column2, column3])
    }
    
    func extractTranslation() -> simd_float4x4 {
        return matrix_float4x4(columns: (vector_float4(1.0, 0.0, 0.0, 0.0),
                                         vector_float4(0.0, 1.0, 0.0, 0.0),
                                         vector_float4(0.0, 0.0, 1.0, 0.0),
                                         vector_float4(columns.3.x, columns.3.y, columns.3.z, 1.0)))
    }
}

extension simd_float3x3 {
    func yaw() -> Float {
        return atan2(-columns.0.z, columns.2.z)
    }
    func pitch() -> Float {
        return asin(columns.1.z)
    }
    func roll() -> Float {
        return atan2(-columns.1.x, columns.1.y)
    }
    func scaleX() -> Float {
        return length(columns.0)
    }
    func scaleY() -> Float {
        return length(columns.1)
    }
    func scaleZ() -> Float {
        return length(columns.2)
    }
}

extension float4x4 {
    var translation: SIMD3<Float> {
        return [columns.3.x,
                columns.3.y,
                columns.3.z]
    }
}

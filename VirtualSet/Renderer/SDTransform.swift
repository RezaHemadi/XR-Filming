//
//  SDTransform.swift
//  VirtualSet
//
//  Created by Reza on 9/26/21.
//

import Foundation
import os.signpost

struct SDTransform {
    var simdTransform: matrix_float4x4
    
    private var columns: (SIMD4<Float>, SIMD4<Float>, SIMD4<Float>, SIMD4<Float>) {
        return simdTransform.columns
    }
    
    init(transform: matrix_float4x4) {
        simdTransform = transform
    }
    
    init(translation: SIMD3<Float>) {
        simdTransform = matrix_float4x4_translation(translationX: translation.x,
                                                         translationY: translation.y,
                                                         translationZ: translation.z)
    }
    
    // MARK: - Methods
    func decompose() -> DecomposedTransform {
        var m = simdTransform
        // Extract Translation
        let translation: vector_float3 = [columns.3.x, columns.3.y, columns.3.z]
        
        var scale = vector_float3()
        scale.x = columns.3.w * sqrt(pow(columns.0.x, 2) + pow(columns.0.y, 2) + pow(columns.0.z, 2))
        scale.y = columns.3.w * sqrt(pow(columns.1.x, 2) + pow(columns.1.y, 2) + pow(columns.1.z, 2))
        scale.z = columns.3.w * sqrt(pow(columns.2.x, 2) + pow(columns.2.y, 2) + pow(columns.2.z, 2))
        
        // Remove Scaling
        for i in [0, 1, 2] {
            guard scale.x != 0.0 else { break }
            m[0][i] /= scale.x
        }
        for i in [0, 1, 2] {
            guard scale.y != 0.0 else { break }
            m[1][i] /= scale.y
        }
        for i in [0, 1, 2] {
            guard scale.z != 0.0 else { break }
            m[2][i] /= scale.z
        }
        m[3][3] = 1.0
        
        // Verify orientation, if necessary invert it
        let temp_z_axis: vector_float3 = simd_cross(vector_float3(m[0][0], m[0][1], m[0][2]),
                                                    vector_float3(m[1][0], m[1][1], m[1][2]))
        if simd_dot(temp_z_axis, vector_float3(m[2][0], m[2][1], m[2][2])) < 0 {
            os_log(.info, "correcting orientation")
            scale.x *= -1
            m[0][0] *= -1
            m[0][1] *= -1
            m[0][2] *= -1
        }
        
        // Extract Rotation
        let theta1: Float = atan2(m[1][2], m[2][2])
        let c2: Float = sqrt(pow(m[0][0], 2) + pow(m[0][1], 2))
        let theta2: Float = atan2(-m[0][2], c2)
        let s1 = sin(theta1)
        let c1 = cos(theta1)
        let theta3 = atan2(s1 * m[2][0] - c1 * m[1][0], c1 * m[1][1] - s1 * m[2][1])
        let rotation: vector_float3 = [-theta1, -theta2, -theta3]
        
        return DecomposedTransform(translation: translation,
                                   scale: scale,
                                   eulerAngles: rotation)
    }
}

struct DecomposedTransform {
    var translation: vector_float3
    var scale: vector_float3
    var eulerAngles: vector_float3
}

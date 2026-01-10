//
//  MediaValidator.swift
//  xPost
//
//  Created by Takekuni Tanemori on 1/10/26.
//

import Foundation
import AVFoundation

struct MediaValidator {
    // Limits based on common social media denominators
    static let maxFileSizeInBytes: Int = 1000 * 1024 * 1024 // 1gb
    static let minDuration: Double = 3.0 // 3 seconds
    static let maxDuration: Double = 600.0 // 10 minutes (varies by platform)

    static func validateVideo(data: Data) throws {
        // 1. Check File Size
        if data.count > maxFileSizeInBytes {
            throw MediaError.fileTooLarge
        }
        
        // 2. Check for empty data
        if data.isEmpty {
            throw MediaError.corruptFile
        }
    }
}

enum MediaError: Error, LocalizedError {
    case fileTooLarge
    case corruptFile
    case unsupportedFormat
    
    var errorDescription: String? {
        switch self {
        case .fileTooLarge: return "Video is too large. Max size is 100MB."
        case .corruptFile: return "The video file appears to be corrupt."
        case .unsupportedFormat: return "Please use .mp4 or .mov files."
        }
    }
}

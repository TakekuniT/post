//
//  ContentValidator.swift
//  xPost
//
//  Created by Takekuni Tanemori on 1/10/26.
//
import Foundation
struct ContentValidator {
    static func sanitize(_ input: String) -> String {
        // Remove HTML tags to prevent XSS and trim whitespace
        let noHTML = input.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        return noHTML.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func validate(caption: String, description: String, platforms: Set<String>) throws {
        let captionCount = caption.count
        let descCount = description.count
        
        // 1. Instagram: 2,200 characters
        if platforms.contains("instagram") && captionCount > 2200 {
            throw PostError.tooLong(platform: "Instagram", limit: 2200)
        }
        
        // 2. LinkedIn: 3,000 characters
        if platforms.contains("linkedin") && captionCount > 3000 {
            throw PostError.tooLong(platform: "LinkedIn", limit: 3000)
        }
        
        // 3. TikTok: 2,200 characters
        if platforms.contains("tiktok") && captionCount > 2200 {
            throw PostError.tooLong(platform: "TikTok", limit: 2200)
        }
        
        // 4. Facebook: 63,206 characters
        // (Essentially unlimited for most users, but good to have a ceiling)
        if platforms.contains("facebook") && captionCount > 63206 {
            throw PostError.tooLong(platform: "Facebook", limit: 63206)
        }
        
        // 5. YouTube
        if platforms.contains("youtube") {
            // YouTube Video/Shorts Title limit is strictly 100 characters
            if captionCount > 100 {
                throw PostError.tooLong(platform: "YouTube Title", limit: 100)
            }
            // YouTube Description limit is 5,000 characters
            if descCount > 5000 {
                throw PostError.tooLong(platform: "YouTube Description", limit: 5000)
            }
        }
    }
}

enum PostError: LocalizedError {
    case emptyCaption
    case tooLong(platform: String, limit: Int)
    case authError
    
    var errorDescription: String? {
        switch self {
        case .emptyCaption: return "Caption cannot be empty."
        case .tooLong(let p, let l): return "\(p) captions must be under \(l) characters."
        case .authError: return "You must be logged in to post."
        }
        
    }
}

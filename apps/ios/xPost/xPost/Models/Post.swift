//
//  Post.swift
//  xPost
//
//  Created by Takekuni Tanemori on 1/3/26.
//

import Foundation

// 'Codable' allows this to be turned into JSON automatically
struct Post: Codable {
    var user_id: String
    var caption: String
    var description: String // for youtube
    var video_path: String
    var platforms: [String]
    var scheduled_at: Date?
}


struct PhotoPost: Codable {
    var user_id: String
    var caption: String
    var photo_paths: [String]
    var platforms: [String]
    var scheduled_at: Date?
}


struct PostModel: Identifiable, Codable, Equatable {
    // This allows ForEach to track your posts using the database ID
    let id: Int64
    let created_at: Date
    let scheduled_at: Date?
    let status: String
    let caption: String?
    let video_path: String
    let platforms: [String]
    let description: String?
    let user_id: UUID
    
    var platform_links: [String: String]?
}



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

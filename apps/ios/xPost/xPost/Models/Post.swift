//
//  Post.swift
//  xPost
//
//  Created by Takekuni Tanemori on 1/3/26.
//

import Foundation

// 'Codable' allows this to be turned into JSON automatically
struct Post: Codable {
    var userId: String
    var caption: String
    var title: String // for youtube
    var videoPath: String
    var platforms: [String] // e.g., ["facebook", "instagram"]
}

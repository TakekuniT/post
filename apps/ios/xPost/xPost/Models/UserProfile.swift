//
//  UserProfile.swift
//  xPost
//
//  Created by Takekuni Tanemori on 1/4/26.
//

import Foundation

struct UserProfile: Codable {
    let id: UUID
    let username: String
    let email: String
    let timeSaved: Int?
    let phoneNumber: String? 
    
    enum CodingKeys: String, CodingKey {
        case id, username, email
        case timeSaved = "time_saved"
        case phoneNumber = "phone_number"
    }
}

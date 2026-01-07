//
//  Subscription.swift
//  xPost
//
//  Created by Takekuni Tanemori on 1/6/26.
//

import Foundation

struct UserSubscription: Codable {
    let userId: UUID
    let tier: String
    let status: String
    let currentPeriodEnd: Date?
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case tier, status
        case currentPeriodEnd = "current_period_end"
    }
}

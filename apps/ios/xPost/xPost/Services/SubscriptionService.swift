//
//  SubscriptionService.swift
//  xPost
//
//  Created by Takekuni Tanemori on 1/6/26.
//
import Foundation
import Supabase

@MainActor
func getCurrentTier() async -> String {
    do {
        let response = try await supabase
            .from("subscriptions")
            .select("user_id, tier, status")
            .single()
            .execute()
        
        // PRINT THE RAW DATA HERE
        print("DEBUG: Raw JSON Response: \(String(data: response.data, encoding: .utf8) ?? "Empty")")
        
        let sub = try JSONDecoder().decode(UserSubscription.self, from: response.data)
        
        if sub.status == "active" || sub.status == "trialing" {
            return sub.tier.lowercased()
        }
        return "free"
    } catch {
        print("DEBUG: Catch Block Error: \(error)")
        return "free"
    }
}

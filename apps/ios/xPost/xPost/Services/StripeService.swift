//
//  StripService.swift
//  xPost
//
//  Created by Takekuni Tanemori on 1/6/26.
//

import Foundation
import Supabase
import Functions

struct CheckoutResponse: Decodable {
    let url: String
}

class StripeService {
    static let shared = StripeService()
    
    // Replace this with your actual Edge Function URL
    private let edgeFunctionURL = URL(string: "https://uuvkxzdgkqjajsjwmxno.supabase.co/functions/v1/create-checkout")!
    
    func createCheckoutSession(tier: String) async throws -> URL? {
        // 1. Get Session for the JWT
        guard let session = try? await supabase.auth.session else {
            throw NSError(domain: "AuthError", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not logged in"])
        }
        
        // 2. Setup Request
        var request = URLRequest(url: edgeFunctionURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 3. Send the tier (pro or elite)
        let body = ["tier": tier]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        // 4. Execute
        let (data, _) = try await URLSession.shared.data(for: request)
        
        // 5. Parse the Stripe URL
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let urlString = json["url"] as? String {
            return URL(string: urlString)
        }
        
        return nil
    }
    
    
    
    
    
}

//
//  AuthService.swift
//  xPost
//
//  Created by Takekuni Tanemori on 1/3/26.
//

import Foundation
import Supabase

class AuthService: ObservableObject {
    static let shared = AuthService()
    
    // Sign up a new user
    func signUp(email: String, pass: String, username: String) async throws {
        let userData: [String: AnyJSON] = [
            "username": .string(username)
        ]

        try await supabase.auth.signUp(
            email: email,
            password: pass,
            data: userData,
            redirectTo: URL(string: "xpost://login-callback")
        )
    }
    
    
    // Sign in an existing user
    func signIn(email: String, pass: String) async throws {
        try await supabase.auth.signIn(email: email, password: pass)
    }
    
    // Request a password reset email
//    func resetPassword(email: String) async throws {
//        try await supabase.auth.resetPasswordForEmail(email)
//    }
    
    func resetPassword(email: String) async throws {
        try await supabase.auth.resetPasswordForEmail(
            email,
            redirectTo: URL(string: "xpost://reset-password")
        )
    }
  
    
    // MARK: - Update Password (Step 2: Save New Password)
    func updatePassword(new: String) async throws {
        let attributes = UserAttributes(password: new)
        try await supabase.auth.update(user: attributes)
    }
    
    
    func fetchLinkedPlatforms() async throws -> [String] {
        let session = try await supabase.auth.session
        let userId = session.user.id

        struct PlatformRow: Decodable {
            let platform: String
        }

       
        let response: [PlatformRow] = try await supabase
            .from("social_accounts")
            .select("platform")
            .eq("user_id", value: userId)
            .execute()
            .value

        
        let platforms = response.map { $0.platform.lowercased() }
        return Array(Set(platforms))
    }
   
}

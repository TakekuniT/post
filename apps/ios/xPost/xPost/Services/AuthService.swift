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
    func signUp(email: String, pass: String) async throws {
        try await supabase.auth.signUp(email: email, password: pass)
    }
    
    // Sign in an existing user
    func signIn(email: String, pass: String) async throws {
        try await supabase.auth.signIn(email: email, password: pass)
    }
    
    // Request a password reset email
    func resetPassword(email: String) async throws {
        try await supabase.auth.resetPasswordForEmail(email)
    }
   
}

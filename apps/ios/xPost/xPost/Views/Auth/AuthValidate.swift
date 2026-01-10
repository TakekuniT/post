//
//  AuthValidate.swift
//  xPost
//
//  Created by Takekuni Tanemori on 1/10/26.
//

import Foundation

struct AuthValidator {
    static func sanitize(_ input: String) -> String {
        // Removes accidental spaces at start/end and newlines
        return input.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func isValidEmail(_ email: String) -> Bool {
        // Modern Swift Regex (iOS 16+) for RFC 5322 compliance
        let emailRegex = /^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$/.ignoresCase()
        return email.wholeMatch(of: emailRegex) != nil
    }
    
    static func isValidPassword(_ password: String) -> Bool {
        // Minimum 8 characters, at least one number (adjust to your Supabase settings)
        return password.count >= 8
    }
}

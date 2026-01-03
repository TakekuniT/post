//
//  SupabaseConfig.swift
//  xPost
//
//  Created by Takekuni Tanemori on 1/3/26.
//

import Foundation
import Supabase

enum SupabaseConfig {
    static let url = URL(string: "https://uuvkxzdgkqjajsjwmxno.supabase.co")!
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InV1dmt4emRna3FqYWpzandteG5vIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjczODAxNzUsImV4cCI6MjA4Mjk1NjE3NX0.44Ce8zZu3INaWBFRQNvqp-_ZyJ8ebVBOKHv9_aCTzmU"
}

// Globally initializes supabase
let supabase = SupabaseClient(
    supabaseURL: SupabaseConfig.url,
    supabaseKey: SupabaseConfig.anonKey
)

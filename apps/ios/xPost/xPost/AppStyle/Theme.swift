//
//  Theme.swift
//  xPost
//
//  Created by Takekuni Tanemori on 1/4/26.
//

import SwiftUI
import UIKit

// MARK: - App Colors
extension Color {
    /// The primary purple used for branding, active states, and icons.
    static let brandPurple = Color(red: 0.55, green: 0.35, blue: 0.95)
    
    /// A muted rose color used for destructive actions (Sign Out, Disconnect).
    static let roseRed = Color(red: 0.85, green: 0.30, blue: 0.45)
    
    /// Adaptive background color for standard system lists.
    static let themeBackground = Color(UIColor.systemGroupedBackground)
}

// MARK: - Haptic Engine
struct Haptics {
    /// Light 'click' for button selections or simple interactions.
    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
    
    /// Satisfying 'double-tap' for successful logins or uploads.
    static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    /// Error haptic for failed refreshes or network issues.
    static func error() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }
}


func formatPlatformName(_ id: String) -> String {
    switch id.lowercased() {
    case "youtube": return "YouTube"
    case "tiktok": return "TikTok"
    case "linkedin": return "LinkedIn"
    case "facebook": return "Facebook"
    case "instagram": return "Instagram"
    default: return id.capitalized
    }
}

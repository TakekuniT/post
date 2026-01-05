//
//  SectionHeader.swift
//  xPost
//
//  Created by Takekuni Tanemori on 1/4/26.
//

import SwiftUI

struct SectionHeader: View {
    let title: String
    let subtitle: String
    let isAnimating: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(.title, design: .rounded, weight: .bold))
            
            Text(subtitle)
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 10)
    }
}

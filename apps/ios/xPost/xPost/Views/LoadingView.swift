//
//  LoginView.swift
//  xPost
//
//  Created by Takekuni Tanemori on 1/10/26.
//
import SwiftUI

struct LoadingView: View {
    var body: some View {
        ZStack {
            // Use your brand color or a standard background
            Color(.systemBackground).ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Use the name you gave it in Assets
                Image("AppIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    // Optional: add a slight round to the corners if it's the icon
                    .cornerRadius(24)
                
                ProgressView()
                    .scaleEffect(1.2)
            }
        }
    }
}

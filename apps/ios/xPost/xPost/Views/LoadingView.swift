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
            ZStack {
                Color.purple.ignoresSafeArea() // Use system purple just to test
                VStack {
                    Image("UniPost1024")
                        .resizable()
                        .frame(width: 100, height: 100)
                }
            }
            
            ZStack {
                // Change this to your actual purple color
                Color.brandPurple.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    Image("UniPost1024") // Ensure this name is exactly the same as in Assets
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                        .cornerRadius(24)
                    
                    ProgressView()
                        .tint(.white) // Make the spinner white so it shows on purple
                        .scaleEffect(1.2)
                }
            }
        }
    }
}

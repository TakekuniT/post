//
//  ForgotPasswordView.swift
//  xPost
//
//  Created by Takekuni Tanemori on 1/3/26.
//
import SwiftUI

struct ForgotPasswordView: View {
    @State private var email = ""
    @State private var message = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Reset Password")
                .font(.title2).bold()
            
            TextField("Enter your email", text: $email)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
            
            Button("Send Reset Link") {
                Task {
                    try? await AuthService.shared.resetPassword(email: email)
                    message = "Check your email for a reset link."
                }
            }
            
            Text(message).foregroundColor(.green)
        }
    }
}

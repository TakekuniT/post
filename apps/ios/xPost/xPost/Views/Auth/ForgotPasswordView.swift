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
    @State private var isLoading = false
    @State private var animationPhase: Int = 0
    @Environment(\.dismiss) var dismiss
    @State private var shakeOffset: CGFloat = 0

    // Helper to wrap the error logic
    func withErrorAnimation(_ action: () -> Void) {
        action() // Change the message text
        
        // Trigger the shake sequence
        withAnimation(.default.repeatCount(3, autoreverses: true).speed(4)) {
            shakeOffset = 6
        }
        // Reset the offset after the animation finishes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            shakeOffset = 0
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // MARK: - Background
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
                
                LinearGradient(colors: [.brandPurple.opacity(0.25), .clear],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {
                        
                        // PHASE 1: Header
                        headerSection
                            .offset(y: animationPhase >= 1 ? 0 : 20)
                            .opacity(animationPhase >= 1 ? 1 : 0)

                        // PHASE 2: Email Input
                        VStack(spacing: 16) {
                            customField(title: "Enter your email", text: $email, icon: "envelope.fill")
                            if !message.isEmpty {
                                let isError = message.contains("valid") || message.contains("enter")
                                
                                HStack {
                                    Image(systemName: isError ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                                    Text(message)
                                }
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundColor(isError ? Color.roseRed : .green) // Red for errors
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background((isError ? Color.red : Color.green).opacity(0.1)) // Red tint background
                                .cornerRadius(10)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
//                            if !message.isEmpty {
//                                HStack {
//                                    Image(systemName: "checkmark.circle.fill")
//                                    Text(message)
//                                }
//                                .font(.system(size: 13, weight: .medium, design: .rounded))
//                                .foregroundColor(.green)
//                                .padding(.vertical, 8)
//                                .padding(.horizontal, 12)
//                                .background(Color.green.opacity(0.1))
//                                .cornerRadius(10)
//                                .transition(.opacity.combined(with: .move(edge: .top)))
//                            }
                        }
                        .padding(.horizontal)
                        .offset(y: animationPhase >= 2 ? 0 : 20)
                        .opacity(animationPhase >= 2 ? 1 : 0)

                        // PHASE 3: Action Buttons
                        VStack(spacing: 20) {
                            Button {
                                handleReset()
                            } label: {
                                Group {
                                    if isLoading {
                                        ProgressView().tint(.white)
                                    } else {
                                        Text("Send Reset Link")
                                            .font(.system(size: 17, weight: .bold, design: .rounded))
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(email.isEmpty ? Color.secondary.opacity(0.3).gradient : Color.brandPurple.gradient)
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                                .shadow(color: email.isEmpty ? .clear : .brandPurple.opacity(0.3), radius: 10, x: 0, y: 5)
                            }
                            .disabled(isLoading || email.isEmpty)
                            
                            Button {
                                dismiss()
                            } label: {
                                Text("Back to Sign In")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(.brandPurple)
                            }
                        }
                        .padding(.horizontal)
                        .offset(y: animationPhase >= 3 ? 0 : 20)
                        .opacity(animationPhase >= 3 ? 1 : 0)
                    }
                    .padding(.top, 20)
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                startAnimations()
            }
        }
    }

    // MARK: - Subcomponents
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Reset Password")
                .font(.system(size: 34, weight: .bold, design: .rounded))
            Text("We'll send a magic link to your inbox.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.top, 24)
    }

    @ViewBuilder
    private func customField(title: String, text: Binding<String>, icon: String) -> some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .foregroundColor(.brandPurple)
                .frame(width: 20)
            
            TextField(title, text: text)
                .font(.system(size: 16, design: .rounded))
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 20).fill(.ultraThinMaterial))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.brandPurple.opacity(0.1), lineWidth: 1)
        )
    }

    // MARK: - Logic
    func startAnimations() {
        animationPhase = 0
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            animationPhase = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                animationPhase = 2
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                animationPhase = 3
            }
        }
    }

    func handleReset() {
        message = ""
        let cleanEmail = AuthValidator.sanitize(email)
        
        guard !cleanEmail.isEmpty else {
            withErrorAnimation { message = "Please enter an email address." }
            Haptics.error()
            return
        }
        if !AuthValidator.isValidEmail(cleanEmail) {
            withErrorAnimation { message = "Please enter a valid email address." }
            Haptics.error()
            return
        }
        Haptics.selection()
        isLoading = true

        Task {
            do {
                try await AuthService.shared.resetPassword(email: cleanEmail)
                withAnimation {
                    message = "Check your email for a reset link."
                }
                Haptics.success()
            } catch {
                // You could add an error message state here as well
                print("Reset error: \(error)")
            }
            isLoading = false
        }
    }
}

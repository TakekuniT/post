//
//  NewPasswordView.swift
//  xPost
//
//  Created by Takekuni Tanemori on 1/5/26.
//

import SwiftUI

struct NewPasswordView: View {
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var animationPhase: Int = 0
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
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

                    // PHASE 2: Input Fields
                    VStack(spacing: 16) {
                        customField(title: "New Password", text: $newPassword, icon: "lock.fill", isSecure: true)
                        customField(title: "Confirm Password", text: $confirmPassword, icon: "checkmark.shield.fill", isSecure: true)
                        
                        if !errorMessage.isEmpty {
                            HStack {
                                Image(systemName: "exclamationmark.circle.fill")
                                Text(errorMessage)
                            }
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.red)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(10)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .padding(.horizontal)
                    .offset(y: animationPhase >= 2 ? 0 : 20)
                    .opacity(animationPhase >= 2 ? 1 : 0)

                    // PHASE 3: Action Button
                    VStack(spacing: 20) {
                        Button {
                            updatePassword()
                        } label: {
                            Group {
                                if isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Update Password")
                                        .font(.system(size: 17, weight: .bold, design: .rounded))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(newPassword.isEmpty ? Color.secondary.opacity(0.3).gradient : Color.brandPurple.gradient)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .shadow(color: newPassword.isEmpty ? .clear : .brandPurple.opacity(0.3), radius: 10, x: 0, y: 5)
                        }
                        .disabled(isLoading || newPassword.isEmpty)
                        
                        Button {
                            dismiss()
                        } label: {
                            Text("Cancel")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    .offset(y: animationPhase >= 3 ? 0 : 20)
                    .opacity(animationPhase >= 3 ? 1 : 0)
                }
                .padding(.top, 24)
            }
        }
        .onAppear {
            startAnimations()
        }
    }

    // MARK: - Subcomponents
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Secure Account")
                .font(.system(size: 34, weight: .bold, design: .rounded))
            Text("Please enter a strong new password below.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.top, 24)
    }

    @ViewBuilder
    private func customField(title: String, text: Binding<String>, icon: String, isSecure: Bool) -> some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .foregroundColor(.brandPurple)
                .frame(width: 20)
            
            if isSecure {
                SecureField(title, text: text)
                    .font(.system(size: 16, design: .rounded))
            } else {
                TextField(title, text: text)
                    .font(.system(size: 16, design: .rounded))
                    .textInputAutocapitalization(.never)
            }
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
    
    

    private func showError(_ msg: String) {
        withAnimation(.spring()) { errorMessage = msg }
        Haptics.error()
    }
    func updatePassword() {
        
        if !AuthValidator.isStrongPassword(newPassword) {
            showError("Password must be 8+ characters, include a number and an uppercase letter.")
            return
        }
        guard newPassword == confirmPassword else {
            showError("Passwords do not match.")
            return
        }
        
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                // Force a refresh or grab current session
                let session = try await supabase.auth.session
                print("DEBUG: Updating password for user: \(session.user.email ?? "Unknown")")

                try await AuthService.shared.updatePassword(new: newPassword)
                Haptics.success()
                dismiss()
            } catch {
                print("DEBUG: Update error: \(error)")
                

                await MainActor.run {
                    withAnimation(.spring()) {
                        let errorString = error.localizedDescription
                        
                        // INTERCEPT SAME PASSWORD ERROR
                        // We check for the raw string or the Supabase error code
                        if errorString.contains("same_password") || errorString.contains("different from the old") {
                            errorMessage = "New password must be different from your old one."
                        } else if errorString.contains("session") {
                            errorMessage = "Session expired. Please click the link in your email again."
                        } else {
                            // Fallback for other errors (network, etc.)
                            errorMessage = error.localizedDescription
                        }
                    }
                }

            }
            isLoading = false
        }
    }
}

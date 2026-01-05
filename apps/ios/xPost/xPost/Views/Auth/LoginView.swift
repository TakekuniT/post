//
//  LoginView.swift
//  xPost
//
//  Created by Takekuni Tanemori on 1/3/26.
//
import SwiftUI

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @Binding var isAuthenticated: Bool
    
    // Animation state
    @State private var animationPhase: Int = 0
    
    var body: some View {
        NavigationStack {
            ZStack {
                // MARK: - Premium Background
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
                
                LinearGradient(colors: [.brandPurple.opacity(0.25), .clear],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {
                        
                        // PHASE 1: Hero Section
                        VStack(spacing: 12) {
                            Text("UniPost")
                                .font(.system(size: 48, weight: .black, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(colors: [.brandPurple, .brandPurple.opacity(0.7)],
                                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                            
                            Text("Welcome back. Your audience is waiting.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 60)
                        .offset(y: animationPhase >= 1 ? 0 : 20)
                        .opacity(animationPhase >= 1 ? 1 : 0)

                        // PHASE 2: Input Fields
                        VStack(spacing: 16) {
                            customField(title: "Email", text: $email, icon: "envelope.fill", isSecure: false)
                            customField(title: "Password", text: $password, icon: "lock.fill", isSecure: true)
                            
                            // Forgot Password Link
                            NavigationLink(destination: ForgotPasswordView()) {
                                Text("Forgot Password?")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundColor(.brandPurple)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                    .padding(.trailing, 8)
                            }
                        }
                        .padding(.horizontal)
                        .offset(y: animationPhase >= 2 ? 0 : 20)
                        .opacity(animationPhase >= 2 ? 1 : 0)

                        // PHASE 3: Action Buttons
                        VStack(spacing: 16) {
                            Button {
                                login()
                            } label: {
                                Group {
                                    if isLoading {
                                        ProgressView().tint(.white)
                                    } else {
                                        Text("Sign In")
                                            .font(.system(size: 17, weight: .bold, design: .rounded))
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color.brandPurple.gradient)
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                                .shadow(color: .brandPurple.opacity(0.3), radius: 10, x: 0, y: 5)
                            }
                            .disabled(isLoading)

                            HStack {
                                Text("New to UniPost?")
                                    .foregroundColor(.secondary)
                                NavigationLink("Create Account", destination: SignUpView())
                                    .fontWeight(.bold)
                                    .foregroundColor(.brandPurple)
                            }
                            .font(.system(size: 14, design: .rounded))
                        }
                        .padding(.horizontal)
                        .offset(y: animationPhase >= 3 ? 0 : 20)
                        .opacity(animationPhase >= 3 ? 1 : 0)
                    }
                }
            }
            .onAppear {
                startAnimations()
            }
        }
    }

    // MARK: - Helper Views
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

    func login() {
        Haptics.selection()
        Task {
            isLoading = true
            do {
                try await AuthService.shared.signIn(email: email, pass: password)
                Haptics.success()
                isAuthenticated = true
            } catch {
                print("Error: \(error.localizedDescription)")
                // Add error haptic here if you have one
            }
            isLoading = false
        }
    }
}

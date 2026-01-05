////
////  SignUpView.swift
////  xPost
////
////  Created by Takekuni Tanemori on 1/3/26.
////
//
//import SwiftUI
//
//struct SignUpView: View {
//    @State private var email = ""
//    @State private var username = ""
//    @State private var password = ""
//    @State private var confirmPassword = ""
//    @State private var errorMessage = ""
//    @State private var isLoading = false
//    @Environment(\.dismiss) var dismiss // To go back to LoginView after success
//
//    var body: some View {
//        VStack(spacing: 20) {
//            Text("Create Account")
//                .font(.largeTitle).bold()
//            
//            VStack(spacing: 15) {
//                // 2. Added the Username TextField
//                TextField("Username", text: $username)
//                    .textFieldStyle(.roundedBorder)
//                    .textInputAutocapitalization(.never)
//                    .autocorrectionDisabled()
//
//                TextField("Email", text: $email)
//                    .textFieldStyle(.roundedBorder)
//                    .textInputAutocapitalization(.never)
//                    .autocorrectionDisabled()
//                
//                SecureField("Password", text: $password)
//                    .textFieldStyle(.roundedBorder)
//                
//                SecureField("Confirm Password", text: $confirmPassword)
//                    .textFieldStyle(.roundedBorder)
//            }
//            .padding(.horizontal)
//            
//            if !errorMessage.isEmpty {
//                Text(errorMessage)
//                    .font(.caption)
//                    .foregroundColor(.red)
//            }
//            
//            Button {
//                handleSignUp()
//            } label: {
//                if isLoading {
//                    ProgressView()
//                } else {
//                    Text("Sign Up").frame(maxWidth: .infinity)
//                }
//            }
//            .buttonStyle(.borderedProminent)
//            // 3. Updated disabled logic to include username
//            .disabled(isLoading || email.isEmpty || password.isEmpty || username.isEmpty)
//            .padding(.horizontal)
//            
//            Spacer()
//        }
//        .padding(.top, 50)
//    }
//    
//    func handleSignUp() {
//        guard password == confirmPassword else {
//            errorMessage = "Passwords do not match"
//            return
//        }
//        
//        // Ensure username isn't empty
//        guard !username.isEmpty else {
//            errorMessage = "Please choose a username"
//            return
//        }
//        
//        Task {
//            isLoading = true
//            errorMessage = ""
//            do {
//                // Pass the username here
//                try await AuthService.shared.signUp(
//                    email: email,
//                    pass: password,
//                    username: username
//                )
//                
//                print("Sign up successful!")
//                dismiss()
//            } catch {
//                errorMessage = error.localizedDescription
//            }
//            isLoading = false
//        }
//    }
//    
//    
//}

import SwiftUI

struct SignUpView: View {
    @State private var email = ""
    @State private var username = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorMessage = ""
    @State private var isLoading = false
    @Environment(\.dismiss) var dismiss
    
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
                        
                        // PHASE 1: Header (Lined up with Dashboard/Upload)
                        headerSection
                            .offset(y: animationPhase >= 1 ? 0 : 20)
                            .opacity(animationPhase >= 1 ? 1 : 0)

                        // PHASE 2: Input Fields
                        VStack(spacing: 16) {
                            customField(title: "Username", text: $username, icon: "person.fill", isSecure: false)
                            customField(title: "Email", text: $email, icon: "envelope.fill", isSecure: false)
                            customField(title: "Password", text: $password, icon: "lock.fill", isSecure: true)
                            customField(title: "Confirm Password", text: $confirmPassword, icon: "checkmark.shield.fill", isSecure: true)
                            
                            if !errorMessage.isEmpty {
                                Text(errorMessage)
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundColor(.red)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                                    .padding(.horizontal, 8)
                            }
                        }
                        .padding(.horizontal)
                        .offset(y: animationPhase >= 2 ? 0 : 20)
                        .opacity(animationPhase >= 2 ? 1 : 0)

                        // PHASE 3: Action Button
                        VStack(spacing: 20) {
                            Button {
                                handleSignUp()
                            } label: {
                                Group {
                                    if isLoading {
                                        ProgressView().tint(.white)
                                    } else {
                                        Text("Create Account")
                                            .font(.system(size: 17, weight: .bold, design: .rounded))
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(
                                    (email.isEmpty || password.isEmpty || username.isEmpty) ?
                                    Color.secondary.opacity(0.3).gradient : Color.brandPurple.gradient
                                )
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                                .shadow(color: (email.isEmpty || password.isEmpty || username.isEmpty) ?
                                        .clear : .brandPurple.opacity(0.3), radius: 10, x: 0, y: 5)
                            }
                            .disabled(isLoading || email.isEmpty || password.isEmpty || username.isEmpty)
                            
                            Button {
                                dismiss()
                            } label: {
                                HStack {
                                    Text("Already have an account?")
                                        .foregroundColor(.secondary)
                                    Text("Sign In")
                                        .fontWeight(.bold)
                                        .foregroundColor(.brandPurple)
                                }
                                .font(.system(size: 14, design: .rounded))
                            }
                        }
                        .padding(.horizontal)
                        .offset(y: animationPhase >= 3 ? 0 : 20)
                        .opacity(animationPhase >= 3 ? 1 : 0)
                    }
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
            Text("Sign Up")
                .font(.system(size: 34, weight: .bold, design: .rounded))
            Text("Join UniPost and amplify your reach.")
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
                    .autocorrectionDisabled()
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

    func handleSignUp() {
        Haptics.selection()
        
        // Client-side validation
        guard !username.isEmpty else {
            withAnimation { errorMessage = "Username cannot be empty" }
            return
        }
        
        guard password == confirmPassword else {
            withAnimation { errorMessage = "Passwords do not match" }
            return
        }
        
        Task {
            isLoading = true
            errorMessage = ""
            do {
                try await AuthService.shared.signUp(
                    email: email,
                    pass: password,
                    username: username
                )
                Haptics.success()
                dismiss()
            } catch {
                // Intercepting specific database errors
                let description = error.localizedDescription.lowercased()
                
                withAnimation(.spring()) {
                    if description.contains("duplicate") || description.contains("already exists") || description.contains("unique") {
                        errorMessage = "This username is already taken."
                    } else if description.contains("email") && description.contains("exists") {
                        errorMessage = "Email is already registered."
                    } else {
                        errorMessage = error.localizedDescription
                    }
                }
                Haptics.error() 
            }
            isLoading = false
        }
    }
}

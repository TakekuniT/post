//
//  SignUpView.swift
//  xPost
//
//  Created by Takekuni Tanemori on 1/3/26.
//

import SwiftUI

struct SignUpView: View {
    @State private var email = ""
    @State private var username = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorMessage = ""
    @State private var isLoading = false
    @Environment(\.dismiss) var dismiss // To go back to LoginView after success

    var body: some View {
        VStack(spacing: 20) {
            Text("Create Account")
                .font(.largeTitle).bold()
            
            VStack(spacing: 15) {
                // 2. Added the Username TextField
                TextField("Username", text: $username)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                TextField("Email", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                
                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)
                
                SecureField("Confirm Password", text: $confirmPassword)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.horizontal)
            
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
            }
            
            Button {
                handleSignUp()
            } label: {
                if isLoading {
                    ProgressView()
                } else {
                    Text("Sign Up").frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            // 3. Updated disabled logic to include username
            .disabled(isLoading || email.isEmpty || password.isEmpty || username.isEmpty)
            .padding(.horizontal)
            
            Spacer()
        }
        .padding(.top, 50)
    }
    
    func handleSignUp() {
        guard password == confirmPassword else {
            errorMessage = "Passwords do not match"
            return
        }
        
        // Ensure username isn't empty
        guard !username.isEmpty else {
            errorMessage = "Please choose a username"
            return
        }
        
        Task {
            isLoading = true
            errorMessage = ""
            do {
                // Pass the username here
                try await AuthService.shared.signUp(
                    email: email,
                    pass: password,
                    username: username
                )
                
                print("Sign up successful!")
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
    
    
}

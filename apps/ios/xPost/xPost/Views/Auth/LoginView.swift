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
    
    var body: some View {
        VStack(spacing: 20) {
            Text("xPost")
                .font(.largeTitle).bold()
            
            VStack {
                TextField("Email", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                
                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.horizontal)
            
            Button {
                login()
            } label: {
                if isLoading {
                    ProgressView()
                } else {
                    Text("Login").frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)
            
            // Navigation Links
            HStack {
                NavigationLink("Create Account", destination: SignUpView())
                Spacer()
                NavigationLink("Forgot Password?", destination: ForgotPasswordView())
            }
            .font(.footnote)
            .padding(.horizontal)
        }
    }
    
    func login() {
        Task {
            isLoading = true
            do {
                try await AuthService.shared.signIn(email: email, pass: password)
                isAuthenticated = true
            } catch {
                print("Error: \(error.localizedDescription)")
            }
            isLoading = false
        }
    }
}

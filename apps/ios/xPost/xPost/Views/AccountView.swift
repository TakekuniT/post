//
//  AccountView.swift
//  xPost
//
//  Created by Takekuni Tanemori on 1/3/26.
//
import SwiftUI
import AuthenticationServices // Required for web login

struct AccountView: View {
    @State private var userEmail: String = "Loading..."
    @State private var userId: String = ""
    @State private var authSession: ASWebAuthenticationSession?
    @State private var authPresenter = WebAuthPresenter()
    
    
    // ngrok or production backend URL
    let backendBaseUrl = "https://youlanda-migratory-trevor.ngrok-free.dev"
    
    final class WebAuthPresenter: NSObject, ASWebAuthenticationPresentationContextProviding {
        func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
            UIApplication.shared
                .connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow } ?? ASPresentationAnchor()
        }
    }
    
    func signOut() {
        Task {
            try? await supabase.auth.signOut()
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section("Profile") {
                    Text("Email: \(userEmail)")
                    Text("ID: \(userId)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("Social Accounts") {
                    Button("Connect TikTok") {
                        print("trying to connect to tiktok")
                        startSocialLogin(platform: "tiktok")
                    }
                    Button("Connect Instagram") {
                        print("trying to connect to instagram")
                        startSocialLogin(platform: "instagram")
                    }
                    Button("Connect YouTube") {
                        print("trying to connect to youtube")
                        startSocialLogin(platform: "youtube")
                    }
                    Button("Connect Facebook") {
                        print("trying to connect to facebook")
                        startSocialLogin(platform: "facebook")
                    }
                }
                
                Section {
                    Button("Sign Out", role: .destructive) {
                        signOut()
                    }
                }
            }
            .navigationTitle("Account")
            .task {
                await fetchUserData()
            }
        }
    }
    
//    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
//        guard
//            let scene = UIApplication.shared.connectedScenes
//                .compactMap({ $0 as? UIWindowScene })
//                .first,
//            let window = scene.windows.first(where: { $0.isKeyWindow })
//        else {
//            return ASPresentationAnchor()
//        }
//        
//        return window
//    }
    
    
    func fetchUserData() async {
        if let session = try? await supabase.auth.session {
            self.userEmail = session.user.email ?? "No Email"
            self.userId = session.user.id.uuidString
        }
    }
    
    func startSocialLogin(platform: String) {
        guard !userId.isEmpty else {
            print("User ID not ready yet")
            return
        }
        
        guard let authURL = URL(
            string: "\(backendBaseUrl)/\(platform)/login?user_id=\(userId)"
        ) else {
            print("Invalid URL")
            return
        }
        
        print("Opening:", authURL)
        
        let session = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: "xpost"
        ) { callbackURL, error in
            if let error = error {
                print("Auth error:", error)
            }
            if let callbackURL = callbackURL {
                print("Callback:", callbackURL)
            }
            self.authSession = nil
        }
        
        session.prefersEphemeralWebBrowserSession = false
        session.presentationContextProvider = authPresenter
        
        self.authSession = session
        
        DispatchQueue.main.async {
            let started = session.start()
            print("Session started:", started)
        }
    }
}

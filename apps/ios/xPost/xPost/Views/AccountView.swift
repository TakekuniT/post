//
//  AccountView.swift
//  xPost
//
//  Created by Takekuni Tanemori on 1/3/26.
//
import SwiftUI
import AuthenticationServices 

struct AccountView: View {
    @State private var userEmail: String = "Loading..."
    @State private var userId: String = ""
    @State private var connectedPlatforms: Set<String> = []
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
                        platformRow(name: "TikTok", id: "tiktok")
                        platformRow(name: "Instagram", id: "instagram")
                        platformRow(name: "YouTube", id: "youtube")
                        platformRow(name: "Facebook", id: "facebook")
                        platformRow(name: "LinkedIn", id: "linkedin")
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
                await checkConnections()
            }
        }
    }
    
    @ViewBuilder
    func platformRow(name: String, id: String) -> some View {
        HStack {
            Text(name)
            Spacer()
            if connectedPlatforms.contains(id) {
                Button("Disconnect") {
                    disconnectPlatform(id)
                }
                .foregroundColor(.red)
            } else {
                Button("Connect") {
                    startSocialLogin(platform: id)
                }
                .foregroundColor(.blue)
            }
        }
    }
    
    func checkConnections() async {
        guard let url = URL(string: "\(backendBaseUrl)/accounts/\(userId)") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let list = try? JSONDecoder().decode([String].self, from: data) {
                DispatchQueue.main.async {
                    self.connectedPlatforms = Set(list)
                }
            }
        } catch {
            print("Failed to fetch connections")
        }
    }
    
    
    func disconnectPlatform(_ platform: String) {
        guard let url = URL(string: "\(backendBaseUrl)/disconnect/\(platform)?user_id=\(userId)") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        URLSession.shared.dataTask(with: request) { _, response, _ in
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                DispatchQueue.main.async {
                    self.connectedPlatforms.remove(platform)
                }
            }
        }.resume()
    }
    
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

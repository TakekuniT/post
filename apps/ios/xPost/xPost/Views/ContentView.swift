

import SwiftUI

struct ContentView: View {
    @State private var isAuthenticated = false
    @State private var showResetSheet = false

    var body: some View {
        Group {
            if isAuthenticated {
                MainTabView()
            } else {
                // No NavigationStack here, LoginView has its own
                LoginView(isAuthenticated: $isAuthenticated)
            }
        }
        // MARK: - Handle Deep Links (Reset Password)
        .sheet(isPresented: $showResetSheet) {
            NewPasswordView()
        }
        .onOpenURL { url in
            handleIncomingURL(url)
        }
        // MARK: - Auth State Listener
        .task {
            // 1. Initial check for existing session
            if let session = try? await supabase.auth.session {
                isAuthenticated = true
            }

            // 2. Listen for real-time changes (Login/Logout)
            for await (event, _) in supabase.auth.authStateChanges {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    if event == .signedIn {
                        isAuthenticated = true
                    } else if event == .signedOut {
                        isAuthenticated = false
                    }
                }
            }
        }
    }
    
    // MARK: - Deep Link Logic
    private func handleIncomingURL(_ url: URL) {
        let urlString = url.absoluteString
        print("DEBUG: Incoming URL: \(urlString)")
        
        // 1. Check if the URL contains the reset-password path and a code
        if urlString.contains("reset-password"),
           let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
           let code = components.queryItems?.first(where: { $0.name == "code" })?.value {
            
            Task {
                do {
                    // 2. Exchange the code for a real session
                    try await supabase.auth.exchangeCodeForSession(authCode: code)
                    print("DEBUG: Session established successfully")
                    
                    await MainActor.run {
                        // 3. Now that the session is live, show the sheet
                        self.showResetSheet = true
                    }
                } catch {
                    print("ERROR: Failed to exchange code: \(error.localizedDescription)")
                }
            }
        }
    }
}
//struct ContentView: View {
//    @State private var isAuthenticated = false
//    @State private var showResetSheet = false
//
//    var body: some View {
//        Group {
//            if isAuthenticated {
//                MainTabView()
//            } else {
//                NavigationStack {
//                    LoginView(isAuthenticated: $isAuthenticated)
//                }
//            }
//        }
//        .task {
//            // 1. Initial check for existing session on launch
//            isAuthenticated = (try? await supabase.auth.session) != nil
//
//            // 2. Listen for real-time auth state changes
//            for await (event, session) in supabase.auth.authStateChanges {
//                // Events include: .signedIn, .signedOut, .userDeleted, etc.
//                if event == .signedIn {
//                    isAuthenticated = true
//                } else if event == .signedOut {
//                    isAuthenticated = false
//                }
//            }
//        }
//    }
//}
//

//
//  AccountView.swift
//  xPost
//
//  Created by Takekuni Tanemori on 1/3/26.
//
import SwiftUI
import AuthenticationServices

final class WebAuthPresenter: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared
            .connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}



struct AnimatedCheckmark: View {
    @State private var percentage: CGFloat = 0

    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 2, y: 5))
            path.addLine(to: CGPoint(x: 5, y: 8))
            path.addLine(to: CGPoint(x: 10, y: 2))
        }
        .trim(from: 0, to: percentage)
        .stroke(Color.brandPurple, lineWidth: 2)
        .frame(width: 12, height: 10)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.2)) {
                percentage = 1
            }
        }
    }
}
struct AccountView: View {
    @State private var userEmail: String = "Loading..."
    @State private var userId: String = ""
    @State private var connectedPlatforms: Set<String> = []
    @State private var authSession: ASWebAuthenticationSession?
    @State private var authPresenter = WebAuthPresenter()
    
    let backendBaseUrl = "https://youlanda-migratory-trevor.ngrok-free.dev"
    
    // SF Symbols for platforms (TikTok and LinkedIn don't have native SF symbols,
    // so we use descriptive ones or specialized icons)
    // Use the exact names from your Assets.xcassets
    let platformAssets: [String: String] = [
        "tiktok": "tiktok",
        "instagram": "instagram",
        "youtube": "youtube",
        "facebook": "facebook",
        "linkedin": "linkedin-in"
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                // Subtle background gradient for a premium feel
                LinearGradient(colors: [.brandPurple.opacity(0.25), .clear],
                               startPoint: .top,
                               endPoint: .bottom)
                    .ignoresSafeArea()

                List {
                    // MARK: - Profile Section
                    Section {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(Color.brandPurple.gradient)
                                    .frame(width: 60, height: 60)
                                Image(systemName: "person.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(.white)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(userEmail)
                                    .font(.system(.title3, design: .rounded, weight: .bold))
                                Text("ID: \(userId.prefix(8))...")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 10)
                    }
                    .listRowBackground(Color.clear) // Transparent row for header

                    // MARK: - Connections Section
                    Section {
                        ForEach(["tiktok", "instagram", "youtube", "facebook", "linkedin"], id: \.self) { platform in
                            platformRow(id: platform)
                        }
                    } header: {
                        Text("Social Connections")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.brandPurple)
                            .padding(.leading, -16)
                    }

                    // MARK: - Danger Zone
                    Section {
                        Button(role: .destructive, action: {
                            Haptics.selection()
                            signOut()
                        }) {
                            HStack {
                                Spacer()
                                Text("Sign Out")
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                            .padding(.vertical, 10)
                            .background(Color.roseRed.opacity(0.12))
                            .foregroundColor(.roseRed)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(Color.roseRed.opacity(0.4), lineWidth: 1.5)
                            )
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden) // Required to see the ZStack gradient
            }
            .navigationTitle("Account")
            .refreshable { await checkConnections() }
            .task {
                await fetchUserData()
                await checkConnections()
            }
        }
    }
    
    
    @ViewBuilder
    func platformRow(id: String) -> some View {
        let isConnected = connectedPlatforms.contains(id)
        let assetName = platformAssets[id] ?? "link"
        
        HStack(spacing: 16) {
            // Icon Container
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.brandPurple.opacity(0.12))
                
                Image(assetName)
                    .resizable()
                    .renderingMode(.template)
                    .aspectRatio(contentMode: .fit)
                    .padding(7)
                    .foregroundColor(.brandPurple)
            }
            .frame(width: 36, height: 36)
            .shadow(color: Color.brandPurple.opacity(0.15), radius: 4, x: 0, y: 2)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(formatPlatformName(id))
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                
                HStack(spacing: 4) {
                    if isConnected {
                        AnimatedCheckmark() // The animated drawing
                        Text("Linked")
                            .font(.caption2)
                            .foregroundColor(.brandPurple)
                            .fontWeight(.bold)
                    } else {
                        Text("Not Linked")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            Button(action: {
                Haptics.selection()
                if isConnected {
                    disconnectPlatform(id)
                } else {
                    startSocialLogin(platform: id)
                }
            }) {
                Text(isConnected ? "Disconnect" : "Connect")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .frame(width: 100)
                    .padding(.vertical, 8)
                    .background(
                        isConnected ?
                        Color.roseRed.opacity(0.12) : // Muted Rose background
                        Color.brandPurple
                    )
                    .foregroundColor(isConnected ? .roseRed : .white)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(isConnected ? Color.roseRed.opacity(0.4) : Color.clear, lineWidth: 1.5)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Logic Updates
    
    func checkConnections() async {
        guard let url = URL(string: "\(backendBaseUrl)/accounts/\(userId)") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let list = try? JSONDecoder().decode([String].self, from: data) {
                let newSet = Set(list)
                
                await MainActor.run {
                    // If we just gained a new connection, vibrate!
                    if newSet.count > self.connectedPlatforms.count {
                        Haptics.success() // Satisfying double-tap haptic
                    }
                    
                    withAnimation(.spring()) {
                        self.connectedPlatforms = newSet
                    }
                }
            }
        } catch {
            print("Failed to fetch connections")
        }
    }
    
    func startSocialLogin(platform: String) {
        guard !userId.isEmpty else { return }
        guard let authURL = URL(string: "\(backendBaseUrl)/\(platform)/login?user_id=\(userId)") else { return }

        let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: "xpost") { _, error in
            if error == nil {
            
                Task {
                    // Small delay to allow backend processing to finish
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    await checkConnections()
                }
            }
            self.authSession = nil
        }
        
        session.presentationContextProvider = authPresenter
        self.authSession = session
        DispatchQueue.main.async { session.start() }
    }

    func disconnectPlatform(_ platform: String) {
        guard let url = URL(string: "\(backendBaseUrl)/disconnect/\(platform)?user_id=\(userId)") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        URLSession.shared.dataTask(with: request) { _, response, _ in
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                Task { await checkConnections() }
            }
        }.resume()
    }

    func fetchUserData() async {
        if let session = try? await supabase.auth.session {
            self.userEmail = session.user.email ?? "No Email"
            self.userId = session.user.id.uuidString
        }
    }

    func signOut() {
        Task { try? await supabase.auth.signOut() }
    }
}
//struct AccountView: View {
//    @State private var userEmail: String = "Loading..."
//    @State private var userId: String = ""
//    @State private var connectedPlatforms: Set<String> = []
//    @State private var authSession: ASWebAuthenticationSession?
//    @State private var authPresenter = WebAuthPresenter()
//    
//    
//    // ngrok or production backend URL
//    let backendBaseUrl = "https://youlanda-migratory-trevor.ngrok-free.dev"
//    
//    let platformIcons: [String: (icon: String, color: Color)] = [
//            "tiktok": ("music.note", .black),
//            "instagram": ("camera.fill", .pink),
//            "youtube": ("play.rectangle.fill", .red),
//            "facebook": ("f.square.fill", .blue),
//            "linkedin": ("person.crop.square.filled.and.at.rectangle", .blue)
//        ]
//
//    
//    final class WebAuthPresenter: NSObject, ASWebAuthenticationPresentationContextProviding {
//        func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
//            UIApplication.shared
//                .connectedScenes
//                .compactMap { $0 as? UIWindowScene }
//                .flatMap { $0.windows }
//                .first { $0.isKeyWindow } ?? ASPresentationAnchor()
//        }
//    }
//    
//    func signOut() {
//        Task {
//            try? await supabase.auth.signOut()
//        }
//    }
//    
//    var body: some View {
//        NavigationStack {
//            List {
//                Section("Profile") {
//                    Text("Email: \(userEmail)")
//                    Text("ID: \(userId)")
//                        .font(.caption)
//                        .foregroundColor(.secondary)
//                }
//                
//                Section("Social Accounts") {
//                        platformRow(name: "TikTok", id: "tiktok")
//                        platformRow(name: "Instagram", id: "instagram")
//                        platformRow(name: "YouTube", id: "youtube")
//                        platformRow(name: "Facebook", id: "facebook")
//                        platformRow(name: "LinkedIn", id: "linkedin")
//                    }
//                Section {
//                    Button("Sign Out", role: .destructive) {
//                        signOut()
//                    }
//                }
//            }
//            .navigationTitle("Account")
//            .task {
//                await fetchUserData()
//                await checkConnections()
//            }
//        }
//    }
//    
//    @ViewBuilder
//    func platformRow(name: String, id: String) -> some View {
//        HStack {
//            Text(name)
//            Spacer()
//            if connectedPlatforms.contains(id) {
//                Button("Disconnect") {
//                    disconnectPlatform(id)
//                }
//                .foregroundColor(.red)
//            } else {
//                Button("Connect") {
//                    startSocialLogin(platform: id)
//                }
//                .foregroundColor(.blue)
//            }
//        }
//    }
//    
//    func checkConnections() async {
//        guard let url = URL(string: "\(backendBaseUrl)/accounts/\(userId)") else { return }
//        do {
//            let (data, _) = try await URLSession.shared.data(from: url)
//            if let list = try? JSONDecoder().decode([String].self, from: data) {
//                DispatchQueue.main.async {
//                    self.connectedPlatforms = Set(list)
//                }
//            }
//        } catch {
//            print("Failed to fetch connections")
//        }
//    }
//    
//    
//    func disconnectPlatform(_ platform: String) {
//        guard let url = URL(string: "\(backendBaseUrl)/disconnect/\(platform)?user_id=\(userId)") else { return }
//        
//        var request = URLRequest(url: url)
//        request.httpMethod = "DELETE"
//        
//        URLSession.shared.dataTask(with: request) { _, response, _ in
//            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
//                DispatchQueue.main.async {
//                    self.connectedPlatforms.remove(platform)
//                }
//            }
//        }.resume()
//    }
//    
//    func fetchUserData() async {
//        if let session = try? await supabase.auth.session {
//            self.userEmail = session.user.email ?? "No Email"
//            self.userId = session.user.id.uuidString
//        }
//    }
//    
//    func startSocialLogin(platform: String) {
//        guard !userId.isEmpty else {
//            print("User ID not ready yet")
//            return
//        }
//        
//        guard let authURL = URL(
//            string: "\(backendBaseUrl)/\(platform)/login?user_id=\(userId)"
//        ) else {
//            print("Invalid URL")
//            return
//        }
//        
//        print("Opening:", authURL)
//        
//        let session = ASWebAuthenticationSession(
//            url: authURL,
//            callbackURLScheme: "xpost"
//        ) { callbackURL, error in
//            if let error = error {
//                print("Auth error:", error)
//            }
//            if let callbackURL = callbackURL {
//                print("Callback:", callbackURL)
//            }
//            self.authSession = nil
//        }
//        
//        session.prefersEphemeralWebBrowserSession = false
//        session.presentationContextProvider = authPresenter
//        
//        self.authSession = session
//        
//        DispatchQueue.main.async {
//            let started = session.start()
//            print("Session started:", started)
//        }
//    }
//}

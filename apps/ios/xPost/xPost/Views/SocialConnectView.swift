//
//  SocialConnectView.swift
//  xPost
//
//  Created by Takekuni Tanemori on 1/4/26.
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

//struct SocialConnectView: View {
//    @State private var userId: String = ""
//    @State private var connectedPlatforms: Set<String> = []
//    @State private var authSession: ASWebAuthenticationSession?
//    @State private var authPresenter = WebAuthPresenter()
//    @State private var isAnimating = false
//    @State private var bounceTrigger = 0
//    
//    let backendBaseUrl = "https://youlanda-migratory-trevor.ngrok-free.dev"
//    
//    let platformAssets: [String: String] = [
//        "tiktok": "tiktok",
//        "instagram": "instagram",
//        "youtube": "youtube",
//        "facebook": "facebook",
//        "linkedin": "linkedin-in"
//    ]
//
//    var body: some View {
//        NavigationStack {
//            ZStack {
//                // MARK: - Background
//                LinearGradient(colors: [.brandPurple.opacity(0.25), .clear],
//                               startPoint: .top,
//                               endPoint: .bottom)
//                    .ignoresSafeArea()
//
//                ScrollView {
//                    VStack(spacing: 25) {
//                        
//                        // MARK: - Header Section
////                        SectionHeader(
////                            title: "Connect Socials",
////                            subtitle: "Link your accounts to sync posts instantly.",
////                            isAnimating: isAnimating
////                        )
//                        ZStack {
//                            Circle()
//                                .fill(Color.brandPurple.opacity(0.1))
//                                .frame(width: 160, height: 160)
//                            
//                            Image(systemName: "link.badge.plus") // Matching the social theme
//                                .font(.system(size: 70, weight: .thin))
//                                .foregroundColor(.brandPurple)
//                                .symbolEffect(.bounce, value: bounceTrigger)
//                        }
//                        .padding(.top, 40)
//                        
//                        VStack(spacing: 8) {
//                            Text("Connect Socials")
//                                .font(.system(.title, design: .rounded, weight: .bold))
//                            
//                            Text("Link your accounts to sync posts instantly.")
//                                .font(.subheadline)
//                                .foregroundColor(.secondary)
//                                .multilineTextAlignment(.center)
//                                .padding(.horizontal, 40)
//                        }
//                        .opacity(isAnimating ? 1 : 0)
//                        .offset(y: isAnimating ? 0 : 10)
//                        
//                        // MARK: - Platform Cards
//                        VStack(spacing: 16) {
//                            let list = ["tiktok", "instagram", "youtube", "facebook", "linkedin"]
//                            ForEach(0..<list.count, id: \.self) { index in
//                                let id = list[index]
//                                platformCard(id: id)
//                                    .opacity(isAnimating ? 1 : 0)
//                                    .offset(y: isAnimating ? 0 : 20)
//                                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(Double(index) * 0.1), value: isAnimating)
//                            }
//                        }
//                        .padding(.horizontal)
//                        
//                        Spacer(minLength: 50)
//                    }
//                    .padding(.top, 0)
//                }
//            }
//            .navigationTitle("Socials")
//            .navigationBarTitleDisplayMode(.inline)
//            .refreshable { await checkConnections() }
//            .onAppear {
//                withAnimation(.easeOut(duration: 0.6)) {
//                    isAnimating = true
//                }
//                bounceTrigger += 1
//            }
//            .task {
//                await fetchUserData()
//                await checkConnections()
//            }
//        }
//    }
//    
//    @ViewBuilder
//    func platformCard(id: String) -> some View {
//        let isConnected = connectedPlatforms.contains(id)
//        let assetName = platformAssets[id] ?? "link"
//        
//        HStack(spacing: 16) {
//            // Icon
//            ZStack {
//                RoundedRectangle(cornerRadius: 12, style: .continuous)
//                    .fill(Color.brandPurple.opacity(0.1))
//                Image(assetName)
//                    .resizable()
//                    .renderingMode(.template)
//                    .aspectRatio(contentMode: .fit)
//                    .frame(width: 24, height: 24)
//                    .foregroundColor(.brandPurple)
//            }
//            .frame(width: 48, height: 48)
//            
//            VStack(alignment: .leading, spacing: 2) {
//                Text(formatPlatformName(id))
//                    .font(.system(.headline, design: .rounded))
//                
//                HStack(spacing: 4) {
//                    if isConnected {
//                        AnimatedCheckmark()
//                        Text("Linked")
//                            .font(.caption2).bold()
//                            .foregroundColor(.brandPurple)
//                    } else {
//                        Text("Not Linked")
//                            .font(.caption2)
//                            .foregroundColor(.secondary)
//                    }
//                }
//            }
//            
//            Spacer()
//            
//            // Fixed-width Button for consistency
//            Button {
//                Haptics.selection()
//                isConnected ? disconnectPlatform(id) : startSocialLogin(platform: id)
//            } label: {
//                Text(isConnected ? "Disconnect" : "Connect")
//                    .font(.system(size: 13, weight: .bold, design: .rounded))
//                    .frame(width: 90) // Standardized width
//                    .foregroundColor(isConnected ? .roseRed : .white)
//                    .padding(.vertical, 8)
//                    .background(isConnected ? Color.roseRed.opacity(0.1) : Color.brandPurple)
//                    .clipShape(Capsule())
//                    .overlay(
//                        Capsule()
//                            .stroke(isConnected ? Color.roseRed.opacity(0.3) : Color.clear, lineWidth: 1)
//                    )
//            }
//        }
//        .padding()
//        .background(
//            RoundedRectangle(cornerRadius: 20, style: .continuous)
//                .fill(.ultraThinMaterial)
//                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
//        )
//    }
//
//    // MARK: - Logic (Unchanged)
//
//    func checkConnections() async {
//        guard !userId.isEmpty, let url = URL(string: "\(backendBaseUrl)/accounts/\(userId)") else { return }
//        do {
//            let (data, _) = try await URLSession.shared.data(from: url)
//            if let list = try? JSONDecoder().decode([String].self, from: data) {
//                let newSet = Set(list)
//                await MainActor.run {
//                    if newSet.count > self.connectedPlatforms.count { Haptics.success() }
//                    withAnimation(.spring()) { self.connectedPlatforms = newSet }
//                }
//            }
//        } catch { print("Connection check failed") }
//    }
//    
//    func startSocialLogin(platform: String) {
//        guard let authURL = URL(string: "\(backendBaseUrl)/\(platform)/login?user_id=\(userId)") else { return }
//        let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: "xpost") { _, _ in
//            Task {
//                try? await Task.sleep(nanoseconds: 1_000_000_000)
//                await checkConnections()
//            }
//        }
//        session.presentationContextProvider = authPresenter
//        self.authSession = session
//        session.start()
//    }
//
//    func disconnectPlatform(_ platform: String) {
//        guard let url = URL(string: "\(backendBaseUrl)/disconnect/\(platform)?user_id=\(userId)") else { return }
//        var request = URLRequest(url: url)
//        request.httpMethod = "DELETE"
//        URLSession.shared.dataTask(with: request) { _, res, _ in
//            if (res as? HTTPURLResponse)?.statusCode == 200 { Task { await checkConnections() } }
//        }.resume()
//    }
//
//    func fetchUserData() async {
//        if let session = try? await supabase.auth.session {
//            self.userId = session.user.id.uuidString
//        }
//    }
//    
//    func formatPlatformName(_ id: String) -> String {
//        id == "tiktok" ? "TikTok" : id.capitalized
//    }
//}


struct SocialConnectView: View {
    @State private var userId: String = ""
    @State private var connectedPlatforms: Set<String> = []
    @State private var authSession: ASWebAuthenticationSession?
    @State private var authPresenter = WebAuthPresenter()
    @State private var isAnimating = false
    @State private var bounceTrigger = 0
    
    let backendBaseUrl = "https://youlanda-migratory-trevor.ngrok-free.dev"
    
    let platformAssets: [String: String] = [
        "tiktok": "tiktok", "instagram": "instagram", "youtube": "youtube",
        "facebook": "facebook", "linkedin": "linkedin-in"
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                // MARK: - Premium Background
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
                
                LinearGradient(colors: [.brandPurple.opacity(0.25), .clear],
                               startPoint: .top,
                               endPoint: .bottom)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 30) {
                        
                        // MARK: - Hero Header
                        // Instead of a giant circle, we use a sleek, integrated icon design
                        VStack(spacing: 15) {
                            ZStack {
                                // Subtle glow behind the icon
                                Circle()
                                    .fill(Color.brandPurple.opacity(0.15))
                                    .frame(width: 100, height: 100)
                                    .blur(radius: 20)
                                
                                Image(systemName: "link.badge.plus")
                                    .font(.system(size: 44, weight: .light))
                                    .foregroundStyle(Color.brandPurple.gradient)
                                    .symbolEffect(.bounce, value: bounceTrigger)
                            }
                            .padding(.top, 20)
                            
                            VStack(spacing: 6) {
                                Text("Social Sync")
                                    .font(.system(size: 34, weight: .bold, design: .rounded))
                                    .tracking(-0.5)
                                
                                Text("Connected accounts are ready for instant posting.")
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 50)
                            }
                        }
                        .opacity(isAnimating ? 1 : 0)
                        .offset(y: isAnimating ? 0 : 15)
                        
                        // MARK: - Connections Grid/List
                        VStack(spacing: 14) {
                            let list = ["tiktok", "instagram", "youtube", "facebook", "linkedin"]
                            ForEach(0..<list.count, id: \.self) { index in
                                let id = list[index]
                                platformCard(id: id)
                                    .opacity(isAnimating ? 1 : 0)
                                    .offset(y: isAnimating ? 0 : 25)
                                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(Double(index) * 0.08), value: isAnimating)
                            }
                        }
                        .padding(.horizontal)
                        
                        // Helpful Tip Card
                        HStack(spacing: 12) {
                            Image(systemName: "sparkles")
                                .foregroundColor(.brandPurple)
                            Text("Pro tip: Connect at least 3 platforms to double your reach.")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Capsule().fill(Color.brandPurple.opacity(0.05)))
                        .padding(.top, 10)
                        
                        Spacer(minLength: 100)
                    }
                }
            }
            // Use an empty title to let the custom "Social Sync" hero text shine
            .navigationTitle("")
            .navigationBarHidden(true)
            .refreshable { await checkConnections() }
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    isAnimating = true
                }
                bounceTrigger += 1
            }
            .task {
                await fetchUserData()
                await checkConnections()
            }
        }
    }
    
    @ViewBuilder
    func platformCard(id: String) -> some View {
        let isConnected = connectedPlatforms.contains(id)
        let assetName = platformAssets[id] ?? "link"
        
        HStack(spacing: 16) {
            // Icon Style: Clean & Modern
            ZStack {
                Circle()
                    .fill(isConnected ? Color.brandPurple.opacity(0.1) : Color.gray.opacity(0.05))
                
                Image(assetName)
                    .resizable()
                    .renderingMode(.template)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 22, height: 22)
                    .foregroundColor(isConnected ? .brandPurple : .secondary)
            }
            .frame(width: 44, height: 44)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(formatPlatformName(id))
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                
                if isConnected {
                    HStack(spacing: 4) {
                        AnimatedCheckmark()
                        Text("Connected")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.brandPurple)
                    }
                } else {
                    Text("Offline")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button {
                Haptics.selection()
                isConnected ? disconnectPlatform(id) : startSocialLogin(platform: id)
            } label: {
                Text(isConnected ? "Unlink" : "Link")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .frame(width: 80)
                    .padding(.vertical, 8)
                    .background(isConnected ? Color.clear : Color.brandPurple)
                    .foregroundColor(isConnected ? .secondary : .white)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(isConnected ? Color.secondary.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 4)
        )
    }

    // MARK: - Logic (Backend Integration)
    // (Functions remain the same for functionality)
    
    func checkConnections() async {
        guard !userId.isEmpty, let url = URL(string: "\(backendBaseUrl)/accounts/\(userId)") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let list = try? JSONDecoder().decode([String].self, from: data) {
                let newSet = Set(list)
                await MainActor.run {
                    if newSet.count > self.connectedPlatforms.count { Haptics.success() }
                    withAnimation(.spring()) { self.connectedPlatforms = newSet }
                }
            }
        } catch { print("Connection check failed") }
    }
    
    func startSocialLogin(platform: String) {
        guard let authURL = URL(string: "\(backendBaseUrl)/\(platform)/login?user_id=\(userId)") else { return }
        let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: "xpost") { _, _ in
            Task {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await checkConnections()
            }
        }
        session.presentationContextProvider = authPresenter
        self.authSession = session
        session.start()
    }

    func disconnectPlatform(_ platform: String) {
        guard let url = URL(string: "\(backendBaseUrl)/disconnect/\(platform)?user_id=\(userId)") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        URLSession.shared.dataTask(with: request) { _, res, _ in
            if (res as? HTTPURLResponse)?.statusCode == 200 { Task { await checkConnections() } }
        }.resume()
    }

    func fetchUserData() async {
        if let session = try? await supabase.auth.session {
            self.userId = session.user.id.uuidString
        }
    }
    
    func formatPlatformName(_ id: String) -> String {
        id == "tiktok" ? "TikTok" : id.capitalized
    }
}

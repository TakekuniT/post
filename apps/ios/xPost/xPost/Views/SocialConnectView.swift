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



struct SocialConnectView: View {
    @Binding var activeTab: Tab
    @State private var userId: String = ""
    @State private var connectedPlatforms: Set<String> = []
    @State private var authSession: ASWebAuthenticationSession?
    @State private var authPresenter = WebAuthPresenter()
    @State private var isAnimating = false
    @State private var bounceTrigger = 0
    @State private var userTier: String = "loading"
    @State private var isShowingUpgradeSheet: Bool = false
    @State private var selectedTooltipMessage: String? = nil
    
    

    private var connectionLimit: Int {
        switch userTier.lowercased() {
        case "pro": return 5
        case "elite": return 20
        default: return 3
        }
    }
    
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
                
                // Background tap dismiss
                if selectedTooltipMessage != nil {
                    Color.white.opacity(0.001)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring()) {
                                selectedTooltipMessage = nil
                            }
                        }
                        .zIndex(90)
                }

                // Tooltip
                if let message = selectedTooltipMessage {
                    VStack {
                        Spacer()

                        HStack(spacing: 12) {
                            Text(message)
                                .font(.system(.subheadline, design: .rounded, weight: .medium))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.leading)

                            Button {
                                withAnimation(.spring()) {
                                    selectedTooltipMessage = nil
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.white.opacity(0.6))
                                    .font(.system(size: 20))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.brandPurple.opacity(0.9))
                        )
                        .padding(.horizontal, 24)
                        .padding(.bottom, 100)
                    }
                    .zIndex(100)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity.combined(with: .scale(scale: 0.9))
                    ))
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
                self.userTier = await getCurrentTier()
                    
            }
            .sheet(isPresented: $isShowingUpgradeSheet) {
                UpgradeTierView(currentTier: userTier, activeTab: $activeTab)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }
    
    @ViewBuilder
    func platformCard(id: String) -> some View {
        let isConnected = connectedPlatforms.contains(id)
        let assetName = platformAssets[id] ?? "link"
        let isLimitReached = connectedPlatforms.count >= connectionLimit
        let canLink = isConnected || !isLimitReached
        
        
        let tooltipMessage: String? = {
            switch id {
            case "facebook":
                return "Facebook account must be a Facebook Page, not personal profiles."
            case "instagram":
                return "Instagram account must be a Professional account linked to a Facebook Page."
            default:
                return nil
            }
        }()

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
                HStack(spacing: 6) {
                    Text(formatPlatformName(id))
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                    if let tooltipMessage {
                        Button {
                            Haptics.selection()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                selectedTooltipMessage = tooltipMessage
                            }
                        } label: {
                            Image(systemName: "info.circle")
                                .font(.caption)
                                .foregroundColor(.brandPurple.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                    }
                }
               
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
                if isConnected {
                    disconnectPlatform(id)
                } else if !isLimitReached {
                    Task {
                        await startSocialLogin(platform: id)
                    }
                } else {
                    // Logic for when they are over the limit
                  
                    isShowingUpgradeSheet = true
                }
//                isConnected ? disconnectPlatform(id) : startSocialLogin(platform: id)
            } label: {
                Text(isConnected ? "Unlink" : "Link")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .frame(width: 80)
                    .padding(.vertical, 8)
                    //.background(isConnected ? Color.clear : Color.brandPurple)
                    //.foregroundColor(isConnected ? .secondary : .white)
                    .background(!isConnected && isLimitReached ? Color.secondary.opacity(0.2) : (isConnected ? Color.clear : Color.brandPurple))
                                .foregroundColor(isConnected || (!isConnected && isLimitReached) ? .secondary : .white)
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
        guard !userId.isEmpty else { return }
            
        do {
            let list = try await AuthService.shared.fetchLinkedPlatforms()
            
            let newSet = Set(list)
            
            await MainActor.run {
                if newSet.count > self.connectedPlatforms.count {
                    Haptics.success()
                }
                
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    self.connectedPlatforms = newSet
                }
                enforceTierLimits()
            }
        } catch {
            print("Sync Error: \(error.localizedDescription)")
        }
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
    }
    
    func startSocialLogin(platform: String) async {
//        guard let authURL = URL(string: "\(backendBaseUrl)/\(platform)/login?user_id=\(userId)") else { return }
        guard let session = try? await supabase.auth.session else { return }
        let token = session.accessToken
        
        guard let authURL = URL(string: "\(backendBaseUrl)/\(platform)/login?token=\(token)") else { return }

        
        let sessionObj = ASWebAuthenticationSession(url: authURL, callbackURLScheme: "xpost") { _, _ in
            Task {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await checkConnections()
            }
        }
        sessionObj.presentationContextProvider = authPresenter
        self.authSession = sessionObj
        sessionObj.start()
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
        id == "tiktok" ? "TikTok":
        id == "youtube" ? "YouTube":
        id == "linkedin" ? "LinkedIn":
        id.capitalized
    }
    
    
    
    func enforceTierLimits() {
        let currentCount = connectedPlatforms.count
        
        if currentCount > connectionLimit {
            let sortedPlatforms = connectedPlatforms.sorted() // Consistent order
            let platformsToRemove = sortedPlatforms.suffix(currentCount - connectionLimit)
            
            for platformId in platformsToRemove {
                print("Auto-disconnecting \(platformId) due to tier limit.")
                disconnectPlatform(platformId)
            }
            
            withAnimation(.spring()) {
                self.connectedPlatforms = Set(sortedPlatforms.prefix(connectionLimit))
            }
            
       
        }
    }
    
    
}

struct UpgradeTierView: View {
    
    let currentTier: String
    @Binding var activeTab: Tab // Add this
    @Environment(\.dismiss) var dismiss
    
    private var tierDisplayName: String {
        switch currentTier.lowercased() {
        case "pro": return "Creator"
        case "elite": return "Elite"
        default: return "Free"
        }
    }

    var body: some View {
        VStack(spacing: 25) {
            Spacer()
            
            // Icon
            Image(systemName: "bolt.shield.fill")
                .font(.system(size: 60))
                .foregroundStyle(LinearGradient(colors: [.brandPurple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
            
            VStack(spacing: 10) {
                Text("Upgrade Your Reach")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                
                Text("You've reached the limit for the \(tierDisplayName) plan. Unlock more platform slots and premium features.")
                    .font(.system(size: 16, design: .rounded))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            }
            
            
            // CTA Button
            Button {
                // Trigger your RevenueCat or StoreKit logic here
                Haptics.selection()
                dismiss()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        activeTab = .account
                    }
                }
            } label: {
                Text("View Pro Plans")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.brandPurple)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal)
            
            Button("Maybe Later") {
                Haptics.selection()
                dismiss()
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding(.top)
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.brandPurple)
                .frame(width: 24)
            Text(text)
                .font(.system(size: 15, weight: .medium, design: .rounded))
        }
    }
}

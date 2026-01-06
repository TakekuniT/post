//
//  DashboardView.swift
//  xPost
//
//  Created by Takekuni Tanemori on 1/3/26.
//

import SwiftUI

import SafariServices

struct MainDashboardView: View {
    @State private var posts: [PostModel] = []
    @State private var animationPhase: Int = 0
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
                
                LinearGradient(colors: [.brandPurple.opacity(0.25), .clear],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {
                        headerSection
                            .offset(y: animationPhase >= 1 ? 0 : 20)
                            .opacity(animationPhase >= 1 ? 1 : 0)
                        
                        let pendingPosts = posts.filter { $0.status == "pending" }
                        if !pendingPosts.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                sectionLabel("In Progress")
                                ForEach(pendingPosts) { post in
                                    PendingPostCard(post: post)
                                }
                            }
                            .offset(y: animationPhase >= 2 ? 0 : 20)
                            .opacity(animationPhase >= 2 ? 1 : 0)
                        }
                        
                       

                        let historyPosts = posts.filter { $0.status != "pending" }
                        VStack(alignment: .leading, spacing: 16) {
                            sectionLabel("Recent Activity")
                            if historyPosts.isEmpty && pendingPosts.isEmpty {
                                emptyState
                            } else {
                                ForEach(historyPosts) { post in
                                    HistoryRow(post: post)
                                }
                            }
                        }
                        .offset(y: animationPhase >= 3 ? 0 : 20)
                        .opacity(animationPhase >= 3 ? 1 : 0)
                    }
                    .padding(.top, 20)
                }
            }
            .navigationBarHidden(true)
            .task {
                // isAnimating = true
                startAnimations()
                await loadData()
            }
            .refreshable {
                startAnimations()
                await loadData()
            }
        }
    }
    
    // MARK: - Animation Sequence
    func startAnimations() {
        // Reset and trigger sequence
        animationPhase = 0
        withAnimation(.easeOut(duration: 0.6)) { animationPhase = 1 }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeOut(duration: 0.6)) { animationPhase = 2 }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeOut(duration: 0.6)) { animationPhase = 3 }
        }
    }
    
    // MARK: - Logic
    func loadData() async {
        do {
            let fetchedPosts = try await PostService.shared.fetchUserPosts()
            await MainActor.run {
//                withAnimation(.spring()) {
//                    self.posts = fetchedPosts
//                }
                self.posts = fetchedPosts
            }
        } catch {
            print("Dashboard fetch error: \(error)")
        }
    }

    // MARK: - Subcomponents
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Dashboard")
                .font(.system(size: 34, weight: .bold, design: .rounded))
            Text("Track your global reach in real-time.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundColor(.secondary)
            .tracking(1.2)
            .padding(.horizontal, 24)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "paperplane.fill")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.3))
            Text("No activity yet")
                .font(.system(.headline, design: .rounded))
                .foregroundColor(.secondary)
            Text("Your scheduled and past posts will appear here.")
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(.secondary.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}


// MARK: - Supporting Views
struct PendingPostCard: View {
    let post: PostModel
    
    @State private var rotation: Double = 0
    @State private var currentProgress: Double = 0.0
    @State private var timeRemaining: String = ""
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                // MARK: - Animated Loading Icon (Matching History Circle)
                ZStack {
                    Circle()
                        .stroke(Color.brandPurple.opacity(0.1), lineWidth: 3)
                        .frame(width: 44, height: 44)
                    
                    Circle()
                        .trim(from: 0, to: 0.3)
                        .stroke(
                            AngularGradient(colors: [.brandPurple, .brandPurple.opacity(0)], center: .center),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .frame(width: 44, height: 44)
                        .rotationEffect(.degrees(rotation))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(post.caption ?? "Video Post")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .lineLimit(1)
                    
                    // MARK: - Platform Icons (Uniform with HistoryRow)
                    HStack(spacing: 6) {
                        Text("Queued")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.brandPurple)
                            .padding(.leading, 4)
                        ForEach(post.platforms, id: \.self) { platform in
                            Image(platform)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 12, height: 12)
                        }
                        
                        
                    }
                }
                
                Spacer()
                
                // MARK: - Time Layout (Uniform with HistoryRow)
                VStack(alignment: .trailing, spacing: 4) {
                    Text(post.scheduled_at ?? Date(), style: .time)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                    
                    Text(timeRemaining)
                        .font(.system(size: 10, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
            
            // MARK: - Accurate Progress Section
            VStack(alignment: .leading, spacing: 8) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.brandPurple.opacity(0.1))
                        Capsule()
                            .fill(Color.brandPurple.gradient)
                            .frame(width: geo.size.width * CGFloat(currentProgress))
                            .animation(.linear(duration: 1.0), value: currentProgress)
                    }
                }
                .frame(height: 6)
                
                HStack {
                    Text("\(Int(currentProgress * 100))%")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(.ultraThinMaterial))
        .padding(.horizontal, 16)
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            updateStatus()
        }
        .onReceive(timer) { _ in
            updateStatus()
        }
    }
    
    func updateStatus() {
        guard let targetDate = post.scheduled_at else { return }
        let now = Date()
        
        // Accurate Progress: Time since creation / Total time until schedule
        let totalDuration = targetDate.timeIntervalSince(post.created_at)
        let elapsed = now.timeIntervalSince(post.created_at)
        
        if targetDate > now {
            // Calculate progress as a percentage of the total wait time
            let calculatedProgress = elapsed / totalDuration
            withAnimation(.linear(duration: 1.0)) {
                // Start at 5% so the bar is always visible even at the start
                currentProgress = max(0.05, min(calculatedProgress, 1.0))
            }
            // Format time remaining (e.g., "In 2 hours")
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            timeRemaining = formatter.localizedString(for: targetDate, relativeTo: now)
        } else {
            currentProgress = 1.0
            timeRemaining = "Posting now..."
        }
    }
}

struct HistoryRow: View {
    let post: PostModel
    @State private var checkmarkScale: CGFloat = 0.5
    @State private var checkmarkOpacity: Double = 0
    @State private var showPlatformPicker = false
    
    // Helper to determine if the post was today
    private var isToday: Bool {
        Calendar.current.isDateInToday(post.created_at)
    }
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(post.status == "published" ? Color.brandPurple.opacity(0.1) : Color.brandPurple.opacity(0.1))
                    .frame(width: 44, height: 44)
                
                Image(systemName: post.status == "published" ? "checkmark" : "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(post.status == "published" ? .brandPurple : .red)
                    .scaleEffect(checkmarkScale)
                    .opacity(checkmarkOpacity)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(post.caption ?? "Video Post")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    Text(post.status.capitalized)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                        .padding(.leading, 4)
                    
                    ForEach(post.platforms, id: \.self) { platform in
                        Image(platform)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 12, height: 12)
                    }
                    
                    
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                if post.status == "published" {
                    Button {
                        showPlatformPicker = true
                    } label: {
                        Image(systemName: "arrow.up.right.circle.fill")
                            .foregroundColor(.brandPurple.opacity(0.8))
                            .font(.system(size: 22))
                    }
                } else {
                    // Shows actual time (e.g., 9:58 AM)
                    Text(post.created_at, style: .time)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
                
                // Smart Relative Date logic
                if isToday {
                    // Shows "2h ago"
                    Text(post.created_at, style: .relative)
                        .font(.system(size: 10, design: .rounded))
                        .foregroundColor(.secondary)
                } else {
                    // Shows "Jan 4, 2026" if it's not today
                    Text(post.created_at, style: .date)
                        .font(.system(size: 10, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 20).fill(.ultraThinMaterial))
        .padding(.horizontal, 16)
        .confirmationDialog("Open Live Post", isPresented: $showPlatformPicker, titleVisibility: .visible) {
                    ForEach(post.platforms, id: \.self) { platform in
                        Button("Open \(platform.capitalized)") {
                            openLink(for: platform)
                        }
                    }
                    Button("Cancel", role: .cancel) { }
                }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                checkmarkScale = 1.0
                checkmarkOpacity = 1.0
            }
        }
    }
    
    
    
    
//    func openLink(for platform: String) {
//        let platformKey = platform.lowercased()
//        
//        // 1. Check if we have the specific direct URL stored in our dictionary
//        if let linkString = post.platform_links?[platformKey],
//           let url = URL(string: linkString) {
//            
//            Haptics.selection()
//            UIApplication.shared.open(url)
//            return
//        }
//        
//        // 2. Fallback: If no link is stored yet, open the general platform website
//        let webFallback = "https://www.\(platformKey).com"
//        if let url = URL(string: webFallback) {
//            UIApplication.shared.open(url)
//        }
//    }
    
    
    
    func openLink(for platform: String) {
        let platformKey = platform.lowercased()
        
        // 1. Get the URL string from the dictionary
        let urlString: String
        if let link = post.platform_links?[platformKey] {
            urlString = link
        } else {
            urlString = "https://www.\(platformKey).com"
        }
        
        guard let url = URL(string: urlString) else { return }
        
        Haptics.selection()
        
        // 2. Platform-Specific Logic
        
        
        // No longer needed
//        if platformKey == "facebook" {
//            // FORCE BROWSER: For Facebook, we use the Safari Controller
//            // to prevent the FB app from hijacking the link.
//            presentSafariBrowser(with: url)
//        } else {
//            // STANDARD: For others (YouTube/TikTok), let them open their apps
//            UIApplication.shared.open(url)
//        }
        UIApplication.shared.open(url)
    }
    
    // MARK: - Browser Presenter
    private func presentSafariBrowser(with url: URL) {
        let safariVC = SFSafariViewController(url: url)
        safariVC.modalPresentationStyle = .pageSheet // Nice sliding sheet look
        
        // We need to find the top-most view controller to present the browser
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            
            var topController = rootVC
            while let presented = topController.presentedViewController {
                topController = presented
            }
            topController.present(safariVC, animated: true)
        }
    }
    
    
    
//    func openLink(for platform: String) {
//        let urlString: String
//        let webFallback = "https://www.\(platform.lowercased()).com"
//        
//        switch platform.lowercased() {
//        case "facebook":
//            // 'fb://' is the standard scheme for the Facebook app
//            urlString = "fb://"
//        case "linkedin":
//            // 'linkedin://' opens the LinkedIn app directly
//            urlString = "linkedin://"
//        case "instagram":
//            urlString = "instagram://app"
//        case "tiktok":
//            urlString = "snssdk1233://"
//        case "youtube":
//            urlString = "youtube://"
//        default:
//            urlString = webFallback
//        }
//        
//        // Attempt to open the App first
//        if let appUrl = URL(string: urlString), UIApplication.shared.canOpenURL(appUrl) {
//            UIApplication.shared.open(appUrl)
//        } else {
//            // If the app isn't installed, open the website in Safari
//            if let webUrl = URL(string: webFallback) {
//                UIApplication.shared.open(webUrl)
//            }
//        }
//    }
}

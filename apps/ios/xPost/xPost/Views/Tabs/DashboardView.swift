//
//  DashboardView.swift
//  xPost
//
//  Created by Takekuni Tanemori on 1/3/26.
//



import SwiftUI
import SafariServices

func platformIcon(for name: String) -> String {
    let lower = name.lowercased()
    return lower == "linkedin" ? "linkedin-in" : lower
}

struct MainDashboardView: View {
    @State private var posts: [PostModel] = []
    @State private var animationPhase: Int = 0
    
    @State private var refreshTimer: Timer? = nil

    // Helper to check if any post is currently uploading
    private var hasActiveUploads: Bool {
        posts.contains { $0.status == "uploading" }
    }

    // MARK: - Computed Lists (List-safe)
    var pendingPosts: [PostModel] {
        posts.filter { $0.status == "pending" }
    }

    var historyPosts: [PostModel] {
        posts.filter { $0.status != "pending" }
    }
    
    
    func startPolling() {
        // Don't start a second timer if one is already running
        guard refreshTimer == nil else { return }
        
        // Poll every 4 seconds
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { _ in
            Task { @MainActor in
                await loadData()
                
                // If everything is finished, stop the timer to save battery
                if !posts.contains(where: { $0.status == "uploading" }) {
                    stopPolling()
                }
            }
        }
    }

    func stopPolling() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    // MARK: - Delete
    func deleteQueuedPost(_ post: PostModel) {
        Haptics.selection()

        Task {
            do {
                // 1. Log the ID being sent to ensure it matches your DB schema
                print("Attempting to delete post with ID: \(post.id)")
                
                try await PostService.shared.deletePost(id: Int(post.id))
                
                await MainActor.run {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                        posts.removeAll { $0.id == post.id }
                    }
                    Haptics.success()
                }
            } catch {
                // 2. IMPORTANT: Print the actual error to the console
                print("DELETION FAILED: \(error.localizedDescription)")
                print("Full error info: \(error)")
                
                await MainActor.run {
                    Haptics.error()
                }
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()

                LinearGradient(
                    colors: [.brandPurple.opacity(0.22), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                List {
                    // MARK: - Header
                    headerSection
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .offset(y: animationPhase >= 1 ? 0 : 20)
                        .opacity(animationPhase >= 1 ? 1 : 0)
                    
                    // MARK: - Pending
                    if !pendingPosts.isEmpty {
                        Section(header: sectionLabel("In Progress")) {
                            ForEach(pendingPosts) { post in
                                PendingPostCard2(post: post)
                                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                                Button(role: .destructive) {
                                                    deleteQueuedPost(post)
                                                } label: {
                                                    Label("Cancel", systemImage: "trash")
                                                }
                                                .tint(.roseRed)
                                            }
//                                PendingPostCard(post: post)
//                                    .padding(.vertical, 6)
//                                    .listRowInsets(EdgeInsets())
//                                    .listRowBackground(Color.clear)
//                                    .listRowSeparator(.hidden)
//                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
//                                        Button(role: .destructive) {
//                                            deleteQueuedPost(post)
//                                        } label: {
//                                            Image(systemName: "xmark.circle.fill")
//                                        }
//                                        .tint(.roseRed)
//                                    }


                            }
                        }
                        .offset(y: animationPhase >= 2 ? 0 : 20)
                        .opacity(animationPhase >= 2 ? 1 : 0)
                    }

                    // MARK: - History
                    Section(header: sectionLabel("Recent Activity")) {
                        if historyPosts.isEmpty && pendingPosts.isEmpty {
                            emptyState
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        } else {
                            ForEach(historyPosts) { post in
                                HistoryRow(post: post)
                                    .padding(.vertical, 6)
                                    .listRowInsets(EdgeInsets())
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                            }
                        }
                    }
                    .offset(y: animationPhase >= 3 ? 0 : 20)
                    .opacity(animationPhase >= 3 ? 1 : 0)
                }
                .listStyle(.plain)
                .scrollIndicators(.hidden)
            }
            .navigationBarHidden(true)
            .task {
                await loadData()
                startLandingSequence()
                if hasActiveUploads {
                    startPolling()
                }
            }
            // Watch for changes in the posts array
            .onChange(of: posts) { oldValue, newValue in
                if newValue.contains(where: { $0.status == "uploading" }) {
                    startPolling()
                }
            }
            .onDisappear {
                stopPolling() // Always clean up when navigating away
            }
            .refreshable { await loadData() }
        }
    }
    
    func startLandingSequence() {
        withAnimation(.easeOut(duration: 0.6)) { animationPhase = 1 }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) { animationPhase = 2 }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) { animationPhase = 3 }
        }
    }

    // MARK: - Data
    func loadData() async {
        do {
            let fetched = try await PostService.shared.fetchUserPosts()
            await MainActor.run {
                withAnimation(.spring()) {
                    posts = fetched
                }
            }
        } catch {
            print("Dashboard error:", error)
        }
    }

    // MARK: - UI Pieces

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Dashboard")
                .font(.system(size: 34, weight: .bold, design: .rounded))
            Text("Track your global reach in real-time.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.top, 12)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundColor(.secondary)
            .tracking(1.2)
            .padding(.horizontal, 24)
            .padding(.top, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "paperplane.fill")
                .font(.system(size: 38))
                .foregroundColor(.secondary.opacity(0.25))
            Text("No activity yet")
                .font(.headline)
            Text("Your scheduled and published posts will appear here.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 64)
    }
}

//
//import SwiftUI
//
//import SafariServices
//
//
//func platformIcon(for name: String) -> String {
//    let lowerName = name.lowercased()
//    if lowerName == "linkedin" {
//        return "linkedin-in"
//    }
//    return lowerName
//}
//
//struct MainDashboardView: View {
//    @State private var posts: [PostModel] = []
//    @State private var animationPhase: Int = 0
//    
//    func formatPlatformName(_ name: String) -> String {
//        switch name.lowercased() {
//        case "youtube":
//            return "YouTube"
//        case "tiktok":
//            return "TikTok"
//        case "linkedin", "linkedin-in":
//            return "LinkedIn"
//        case "facebook":
//            return "Facebook"
//        case "instagram":
//            return "Instagram"
//        default:
//            return name.capitalized // Fallback for unknown platforms
//        }
//    }
//    
//   
//    
//    
//    
//    
//    
//    // MARK: - Logic (inside MainDashboardView)
//    
//    func deleteQueuedPost(post: PostModel) {
//        // Immediate haptic feedback for the "swipe click"
//        Haptics.error()
//
//        Task {
//            do {
//                try await PostService.shared.deletePost(id: Int(post.id))
//                
//                await MainActor.run {
//                    // Spring stiffness 120 / damping 14 is great,
//                    // but .interactiveSpring() feels better for gestures.
//                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)) {
//                        posts.removeAll { $0.id == post.id }
//                    }
//                    Haptics.success()
//                }
//            } catch {
//                Haptics.error()
//            }
//        }
//    }
//    
//    
//    
//    
//    var body: some View {
//        NavigationStack {
//            ZStack {
//                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
//                
//                LinearGradient(colors: [.brandPurple.opacity(0.25), .clear], startPoint: .top, endPoint: .bottom)
//                    .ignoresSafeArea()
//                
//                
//                
//                
//                
//                
//                
//                
//                
//                
//                
//                
//                ScrollView(showsIndicators: false) {
//                    LazyVStack(spacing: 32) {
//                        headerSection
//                            .offset(y: animationPhase >= 1 ? 0 : 20)
//                            .opacity(animationPhase >= 1 ? 1 : 0)
//                        
//                        let pendingPosts = posts.filter { $0.status == "pending" }
//                        if !pendingPosts.isEmpty {
//                            VStack(alignment: .leading, spacing: 16) {
//                                sectionLabel("In Progress")
//                                
//                                ForEach(pendingPosts) { post in
//                                    PendingPostCard(post: post)
//                                        // This ensures it slides and fades out smoothly
//                                        .transition(.asymmetric(
//                                            insertion: .opacity.combined(with: .move(edge: .bottom)),
//                                            removal: .scale(scale: 0.8).combined(with: .opacity)
//                                        ))
//                                        .contextMenu {
//                                            Button(role: .destructive) {
//                                                deleteQueuedPost(post: post)
//                                            } label: {
//                                                Label("Cancel Post", systemImage: "trash")
//                                            }
//                                        }
//                                }
//                                
//                            }
//                            .offset(y: animationPhase >= 2 ? 0 : 20)
//                            .opacity(animationPhase >= 2 ? 1 : 0)
//                            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: pendingPosts.count)
//                        }
//                        
//                       
//
//                        let historyPosts = posts.filter { $0.status != "pending" }
//                        VStack(alignment: .leading, spacing: 16) {
//                            sectionLabel("Recent Activity")
//                            if historyPosts.isEmpty && pendingPosts.isEmpty {
//                                emptyState
//                            } else {
//                                ForEach(historyPosts) { post in
//                                    HistoryRow(post: post)
//                                }
//                            }
//                        }
//                        .offset(y: animationPhase >= 3 ? 0 : 20)
//                        .opacity(animationPhase >= 3 ? 1 : 0)
//                    }
//                    .padding(.top, 20)
//                    
//                    
//                   
//                    
//                    
//                    
//                }
//                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: posts)
//            }
//            .navigationBarHidden(true)
//            .task {
//                // isAnimating = true
//                startAnimations()
//                await loadData()
//            }
//            .refreshable {
//                startAnimations()
//                await loadData()
//            }
//            
//        }
//    }
//    
//    // MARK: - Animation Sequence
//    func startAnimations() {
//        // Reset and trigger sequence
//        animationPhase = 0
//        withAnimation(.easeOut(duration: 0.6)) { animationPhase = 1 }
//        
//        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
//            withAnimation(.easeOut(duration: 0.6)) { animationPhase = 2 }
//        }
//        
//        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
//            withAnimation(.easeOut(duration: 0.6)) { animationPhase = 3 }
//        }
//    }
//    
//    // MARK: - Logic
//    func loadData() async {
//        do {
//            let fetchedPosts = try await PostService.shared.fetchUserPosts()
//            await MainActor.run {
//                withAnimation(.spring()) {
//                    self.posts = fetchedPosts
//                }
//                //self.posts = fetchedPosts
//            }
//        } catch {
//            print("Dashboard fetch error: \(error)")
//        }
//    }
//    
//    
//
//    // MARK: - Subcomponents
//    private var headerSection: some View {
//        VStack(alignment: .leading, spacing: 8) {
//            Text("Dashboard")
//                .font(.system(size: 34, weight: .bold, design: .rounded))
//            Text("Track your global reach in real-time.")
//                .font(.subheadline)
//                .foregroundColor(.secondary)
//        }
//        .frame(maxWidth: .infinity, alignment: .leading)
//        .padding(.horizontal)
//    }
//
//    private func sectionLabel(_ text: String) -> some View {
//        Text(text.uppercased())
//            .font(.system(size: 12, weight: .bold, design: .rounded))
//            .foregroundColor(.secondary)
//            .tracking(1.2)
//            .padding(.horizontal, 24)
//    }
//
//    private var emptyState: some View {
//        VStack(spacing: 12) {
//            Image(systemName: "paperplane.fill")
//                .font(.system(size: 40))
//                .foregroundColor(.secondary.opacity(0.3))
//            Text("No activity yet")
//                .font(.system(.headline, design: .rounded))
//                .foregroundColor(.secondary)
//            Text("Your scheduled and past posts will appear here.")
//                .font(.system(.subheadline, design: .rounded))
//                .foregroundColor(.secondary.opacity(0.7))
//                .multilineTextAlignment(.center)
//                .padding(.horizontal, 40)
//        }
//        .frame(maxWidth: .infinity)
//        .padding(.vertical, 60)
//    }
//}
//
//


// MARK: - Supporting Views
struct PendingPostCard: View {
    let post: PostModel
    
    @State private var rotation: Double = 0
    @State private var currentProgress: Double = 0.0
    @State private var timeRemaining: String = ""
    @State private var isVisible: Bool = false
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
                            Image(platformIcon(for: platform))
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
    @State private var loadingRotation: Double = 0
    
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
                
                if post.status == "published" {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.brandPurple)
                        .scaleEffect(checkmarkScale)
                        .opacity(checkmarkOpacity)
                } else if post.status == "uploading" {
                    BrandedSpinner()
                } else {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.roseRed)
                        .scaleEffect(checkmarkScale)
                        .opacity(checkmarkOpacity)
                }
                
//                Image(systemName: post.status == "published" ? "checkmark" : "xmark")
//                    .font(.system(size: 14, weight: .bold))
//                    .foregroundColor(post.status == "published" ? .brandPurple : .red)
//                    .scaleEffect(checkmarkScale)
//                    .opacity(checkmarkOpacity)
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
                        Image(platformIcon(for: platform))
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
                Button("Open on \(formatPlatformName(platform))") {
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
    
}





struct PendingPostCard2: View {
    @State private var timeRemaining: String = ""
    let post: PostModel
    @State private var currentProgress: Double = 0.0


    var body: some View {
        HStack(alignment: .top, spacing: 14) {

            // Platform accent bar
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.brandPurple)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 8) {

                // Caption
                Text(post.caption ?? "Untitled post")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(2)

                // Metadata row
                HStack(spacing: 12) {

                   
                    
                    // MARK: - Platform Icons (Uniform with HistoryRow)
                    HStack(spacing: 6) {
                        Text("Queued")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.brandPurple)
                            .padding(.leading, 4)
                        ForEach(post.platforms, id: \.self) { platform in
                            Image(platformIcon(for: platform))
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 12, height: 12)
                        }
                        
                        
                    }

                    Spacer()

                    // Scheduled time
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(post.scheduled_at ?? Date(), style: .time)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                        
                        Text(timeRemaining)
                            .font(.system(size: 10, design: .rounded))
                            .foregroundColor(.secondary)
                    }
//                    if let date = post.scheduled_at {
//                        Text(date, style: .time)
//                            .font(.caption)
//                            .foregroundColor(.secondary)
//                    }
                }
            }
            .onAppear {
                updateStatus()
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        //.background(Color(.secondarySystemGroupedBackground))
        .background(Rectangle().fill(.ultraThinMaterial))
        .listRowInsets(EdgeInsets())          // edge-to-edge row
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    // MARK: - Helpers

    private var formattedPlatforms: String {
        post.platforms
            .map { $0.capitalized }
            .joined(separator: " • ")
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


struct BrandedSpinner: View {
    @State private var isAnimating = false
    
    var body: some View {
        Circle()
            .trim(from: 0, to: 0.3)
            .stroke(
                AngularGradient(
                    colors: [.brandPurple, .brandPurple.opacity(0)],
                    center: .center
                ),
                style: StrokeStyle(lineWidth: 3, lineCap: .round)
            )
            .frame(width: 24, height: 24)
            .rotationEffect(.degrees(isAnimating ? 360 : 0))
            .onAppear {
                withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                    isAnimating = true
                }
            }
    }
}

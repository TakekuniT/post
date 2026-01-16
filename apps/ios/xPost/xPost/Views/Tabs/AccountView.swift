//
//  AccountView.swift
//  xPost
//
//  Created by Takekuni Tanemori on 1/3/26.
//


import SwiftUI
import AuthenticationServices
import SafariServices


enum PlanTier: String, CaseIterable {
    case free, pro, elite
    
    var displayName: String {
        switch self {
        case .free: return "Starter"
        case .pro: return "Creator"
        case .elite: return "Agency"
        }
    }
    
    var price: String {
        switch self {
        case .free: return "Free"
        case .pro: return "$9.99/mo"
        case .elite: return "$29.99/mo"
        }
    }
}

struct AccountView: View {
    @State private var userEmail: String = "Loading..."
    @State private var userName: String = "User"
    @State private var userId: String = ""
    @State private var userTier: String = "loading"
    @State private var selectedPerkMessage: String? = nil
    
    @State private var isAnimating = false
    @State private var showDeleteAlert = false
    
    //@State private var isProcessingPayment = false
    @State private var processingTier: String? = nil
    @State private var checkoutURL: URL?
    @State private var showSafari = false
    @State private var showCards = false
    @State private var showSideMenu = false
    @State private var sideMenuOffset: CGFloat = 0
    @State private var iconScale: CGFloat = 0.6 // Start small
    
    
    private func openLink(_ urlString: String) {
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
    
    // MARK: - Plan Configuration
    private var currentPlanName: String {
        switch userTier.lowercased() {
        case "free": return "Starter"
        case "pro": return "Creator"
        case "elite": return "Agency"
        default: return "Starter"
        }
    }

    private var planPrice: String {
        switch userTier.lowercased() {
        case "pro": return "$9.99/mo"
        case "elite": return "$29.99/mo"
        default: return "Free"
        }
    }
    
    private var backgroundLayers: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
            
            LinearGradient(colors: [.brandPurple.opacity(0.25), .clear],
                           startPoint: .top,
                           endPoint: .bottom)
                .ignoresSafeArea()
        }
        
    }
    
    private var dismissalOverlay: some View {
        Color.white.opacity(0.001) // Using 0.001 makes it "hittable" but invisible
            .ignoresSafeArea()
            .onTapGesture {
                withAnimation(.spring()) {
                    selectedPerkMessage = nil
                }
            }
            .zIndex(90)
    }
    
    private var profileHeader: some View {
        VStack(spacing: 15) {
            ZStack {
                Circle()
                    .fill(Color.brandPurple.opacity(0.15))
                    .frame(width: 100, height: 100)
                    .blur(radius: 20)
                    .scaleEffect(iconScale)
                 
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(Color.brandPurple.gradient)
                    .scaleEffect(iconScale)
            }
            .padding(.top, 20)
            
            VStack(spacing: 4) {
                Text(userName)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text(userEmail)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 15)
        .onAppear{
            iconScale = 0.6
            withAnimation(.spring(response: 0.5, dampingFraction: 0.5, blendDuration: 0)) {
                        iconScale = 1.0
                        isAnimating = true
                    }
        }
    }
    
    private var subscriptionCarousel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Subscription Plans")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 24)
                .opacity(showCards ? 1 : 0)
                .offset(x: showCards ? 0 : -10)
                .animation(
                        .spring(response: 0.6, dampingFraction: 0.8)
                        .delay(0.05), 
                        value: showCards
                    )
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
//                    ForEach(PlanTier.allCases, id: \.self) { plan in
//                        tierCard(for: plan)
//                            .opacity(showCards ? 1 : 0)
//                            .offset(x: showCards ? 0 : 50)
//                            
//                    }
                    ForEach(Array(PlanTier.allCases.enumerated()), id: \.element) { index, plan in
                                        tierCard(for: plan)
                        .opacity(showCards ? 1 : 0)
                        .offset(y: showCards ? 0 : 30) // Slide up effect
                        .animation(
                            .spring(response: 0.6, dampingFraction: 0.8)
                            .delay(Double(index) * 0.15), // Staggered delay
                            value: showCards
                        )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            
            Text("Once a subscription is canceled, your card will no longer be charged and the plan will be reverted to the Starter tier at the end of the billing period.")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.8))
                    .padding(.horizontal, 32)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            accountActionRow(title: "Sign Out", icon: "rectangle.portrait.and.arrow.right", color: .primary) {
                Haptics.selection()
                signOut()
            }
            
            accountActionRow(title: "Delete Account", icon: "trash", color: .roseRed) {
                Haptics.selection()
                showDeleteAlert = true
            }
        }
        .padding(.horizontal)
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 25)
        .animation(.spring().delay(0.2), value: isAnimating)
    }
    private var footerInfo: some View {
        //Text("User ID: \(userId.prefix(12))...")
        Text("© 2026 Takekuni Tanemori. All Rights Reserved.")
            .font(.system(.caption2, design: .monospaced))
            .foregroundColor(.secondary.opacity(0.5))
            .padding(.top, 10)
    }
    
    private var perkOverlay: some View {
        Group {
            if let message = selectedPerkMessage {
                VStack {
                    Spacer()
                    HStack(spacing: 12) {
                        Text(message)
                            .font(.system(.subheadline, design: .rounded, weight: .medium))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Button {
                            withAnimation(.spring()) { selectedPerkMessage = nil }
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
    }
    var body: some View {
        NavigationStack {
            ZStack {
                
                backgroundLayers
                
                if selectedPerkMessage != nil {
                    dismissalOverlay
                }

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 25) {
                        profileHeader
                        subscriptionCarousel
                        actionButtons
                        footerInfo
                        
                    }
                    .padding(.bottom, 30)
                }
                .blur(radius: showSideMenu ? 4 : 0)
                .disabled(showSideMenu)
                
                perkOverlay
                
                if showSideMenu {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                showSideMenu = false
                            }
                        }
                        .transition(.opacity)
                        .zIndex(150)
                }
                
                sideMenuView
                    .offset(x: showSideMenu ? 0 : UIScreen.main.bounds.width)
                    .zIndex(200)

            }
            .navigationTitle("")
            //.navigationBarHidden(true)
            .alert("Delete Account", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) { deleteAccount() }
            } message: {
                Text("This action is permanent and will remove all your scheduled posts.")
            }
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    isAnimating = true
                    showCards = true
                }
            }
            .task {
                await fetchUserData()
                self.userTier = await getCurrentTier()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Haptics.selection()
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showSideMenu.toggle()
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.brandPurple)
                    }
                }
            }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            
            
        }

        .sheet(isPresented: $showSafari) {
            if let url = checkoutURL {
                SafariView(url: url)
                    .ignoresSafeArea()
            }
        }
        
    }
    
    private var sideMenuView: some View {
        HStack(spacing: 0) {
            Spacer() // Pushes the menu to the right
            
            VStack(alignment: .leading, spacing: 20) {
                Text("Support & Legal")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .padding(.top, 60)
                    .padding(.horizontal)

                List {
                    Section("Help") {
                        sideMenuLink(title: "Report a Bug", icon: "ladybug.fill", url: "https://unicore-app-web.vercel.app/report-bug")
                        sideMenuLink(title: "Feature Request", icon: "lightbulb.fill", url: "https://unicore-app-web.vercel.app/feature-request")
                        sideMenuLink(title:"Connect Instagram to Facebook Page", icon: "link", url:"https://www.facebook.com/business/help/connect-instagram-to-page")
                        sideMenuLink(title: "Contact Us", icon: "envelope.fill", url: "mailto:taki.unicore@gmail.com")
                    }
                    
                    Section("Community") {
                        sideMenuLink(title: "Join our Discord", icon: "bubble.left.and.bubble.right.fill", url: "https://discord.gg/mE4jRDqMZU")
                    }
                    
                    Section("Legal") {
                        sideMenuLink(title: "Privacy Policy", icon: "shield.lefthalf.filled", url: "https://unicore-app-web.vercel.app/privacy")
                        sideMenuLink(title: "Terms of Service", icon: "doc.text.fill", url: "https://unicore-app-web.vercel.app/terms")
                        sideMenuLink(title: "Refund Policy", icon:"dollarsign.arrow.circlepath", url:"https://unicore-app-web.vercel.app/refund-policy")
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .frame(width: UIScreen.main.bounds.width * 0.75)
            .background(.ultraThinMaterial)
            .overlay(
                Rectangle()
                    .fill(Color.brandPurple.opacity(0.1))
                    .frame(width: 1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            )
        }
    }
    
    private func sideMenuLink(title: String, icon: String, url: String) -> some View {
        Link(destination: URL(string: url)!) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.brandPurple)
                    .frame(width: 24)
                Text(title)
                    .font(.system(.body, design: .rounded))
            }
        }
        .foregroundColor(.primary)
    }

    // MARK: - Subcomponents
    
    @ViewBuilder
    func accountActionRow(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: 25)
                Text(title)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundColor(color)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 18).fill(.ultraThinMaterial))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func perkRow(icon: String, text: String, isLimit: Bool = false, detailMessage: String? = nil) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isLimit ? .secondary.opacity(0.8) : .brandPurple)
                .frame(width: 24)
            
            Text(text)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(isLimit ? .secondary : .primary)
                
            Spacer()
            
            if isLimit, let message = detailMessage {
                Button {
                    Haptics.selection()
                    withAnimation(.spring()) {
                        selectedPerkMessage = message
                    }
                } label: {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundColor(.brandPurple.opacity(0.6))
                        .contentShape(Rectangle()) // Makes the whole padded area tappable
                        .highPriorityGesture(
                            TapGesture().onEnded {
                                Haptics.selection()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedPerkMessage = message
                                }
                            }
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    @ViewBuilder
    private func tierCard(for plan: PlanTier) -> some View {
        let isCurrentPlan = userTier.lowercased() == plan.rawValue
        let tierWeights: [String: Int] = ["free": 0, "pro": 1, "elite": 2]
        let currentWeight = tierWeights[userTier.lowercased()] ?? 0
        let cardWeight = tierWeights[plan.rawValue] ?? 0
        
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(plan.displayName)
                    .font(.caption.bold())
                    .foregroundColor(isCurrentPlan ? .white : .brandPurple)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(isCurrentPlan ? Color.brandPurple : Color.brandPurple.opacity(0.1))
                    .clipShape(Capsule())
                    .animation(.spring(), value: isCurrentPlan)
                
                Spacer()
                
                if isCurrentPlan {
                    Text("Current")
                        .font(.caption2.bold())
                        .foregroundColor(.secondary)
                        .transition(.opacity.combined(with: .scale))
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(plan.price)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text("Billed monthly")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider().background(Color.brandPurple.opacity(0.2))
            
            VStack(alignment: .leading, spacing: 10) {
                if plan == .free {
                    perkRow(
                        icon: "number.circle.fill",
                        text: "10 Posts per Month",
                        isLimit: true,
                        detailMessage: "The Starter plan allows for 10 total posts across all platforms every 30 days.")
                    perkRow(
                        icon: "clock.badge.exclamationmark",
                        text: "No Scheduled Posts",
                        isLimit: true,
                        detailMessage: "Scheduling is a premium feature. Starter users can only publish posts immediately."
                    )
                    perkRow(
                        icon: "square.dashed",
                        text: "Watermarked Videos",
                        isLimit: true,
                        detailMessage: "Videos exported on the free tier include a small watermark."
                    )
                    perkRow(
                        icon: "tag.fill",
                        text: "Branded Captions",
                        isLimit: true,
                        detailMessage: "Captions on the free tier include 'Sent via UniCore on iOS' with UniCore tags to support our community."
                    )
                    perkRow(
                        icon: "network",
                        text: "Post to 3 Platforms",
                        isLimit: true,
                        detailMessage: "Connect up to 3 social accounts."
                    )

                } else if plan == .pro {
                    perkRow(icon: "infinity", text: "Unlimited Posts")
                    perkRow(icon: "calendar.badge.plus", text: "Full Scheduling Access")
                    perkRow(icon: "checkmark.seal.fill", text: "No Watermarks")
                    perkRow(
                        icon: "tag.fill",
                        text: "Branded Captions",
                        isLimit: true,
                        detailMessage: "Captions on the free tier includes 'Sent via UniCore on iOS' with UniCore tags to support our community."
                    )
                    perkRow(
                        icon: "network",
                        text: "Post to 5 Platforms",
                        isLimit: true,
                        detailMessage: "Connect up to 5 social accounts."
                    )
                } else {
                    perkRow(icon: "infinity", text: "Unlimited Posts")
                    perkRow(icon: "calendar.badge.plus", text: "Full Scheduling Access")
                    perkRow(icon: "sparkles", text: "No Watermarks or Branding")
                    perkRow(icon: "globe", text: "All Platforms Enabled")
                    perkRow(icon: "bolt.fill", text: "Priority Support")
                }
            }
            
            Spacer(minLength: 20)
            
            Button {
                if !isCurrentPlan {
                    if cardWeight < currentWeight {
                        // DOWNGRADE LOGIC: Open the Customer Portal
                        Haptics.selection()
                        // Replace the URL below with the "test link" you just activated in Stripe
                        if let portalURL = URL(string: "https://billing.stripe.com/p/login/test_fZu14m7W657s7Qwex11Nu00") {
                            UIApplication.shared.open(portalURL)
                        }
                    } else {
                        Haptics.success()
                        Task {
                            await MainActor.run { processingTier = plan.rawValue }
                            do {
                                if let url = try await StripeService.shared.createCheckoutSession(tier: plan.rawValue) {
                                    await MainActor.run {
                                        self.checkoutURL = url
                                        self.showSafari = true
                                    }
                                }
                            } catch {
                                print("Stripe Error: \(error.localizedDescription)")
                            }
                            await MainActor.run { processingTier = nil }
                        }
                    }
                    
                }
            } label: {
                if processingTier == plan.rawValue {
                    ProgressView()
                        .tint(Color.brandPurple)
                        .frame(maxWidth: .infinity)
                } else {
                    Text(buttonText(isCurrent: isCurrentPlan, currentWeight: currentWeight, cardWeight: cardWeight))
                        .font(.system(.callout, design: .rounded, weight: .bold))
                        .foregroundColor(isCurrentPlan ? .brandPurple : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(isCurrentPlan ? Color.clear : Color.brandPurple)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isCurrentPlan ? Color.brandPurple.opacity(0.3) : Color.clear, lineWidth: 1.5)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .disabled(processingTier != nil)
            .animation(.easeInOut(duration: 0.3), value: isCurrentPlan)
        }
        .padding(20)
        .frame(width: 280, height: 380)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(isCurrentPlan ? Color.brandPurple.opacity(0.5) : Color.white.opacity(0.2), lineWidth: 2)
                )
        )
        //.scaleEffect(isCurrentPlan ? 1.02 : 1.0) // Subtle pop for current plan
        //.animation(.spring(), value: isCurrentPlan)
    }

    // MARK: - Logic
    
    func fetchUserData() async {
        guard let session = try? await supabase.auth.session else { return }
        self.userEmail = session.user.email ?? "No Email"
        self.userId = session.user.id.uuidString
        
        do {
            let profile: UserProfile = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: session.user.id)
                .single()
                .execute()
                .value
            
            await MainActor.run {
                self.userName = profile.username
            }
        } catch {
            print("Profile fetch error: \(error)")
        }
    }

    func buttonText(isCurrent: Bool, currentWeight: Int, cardWeight: Int) -> String {
        if isCurrent { return "Current Plan" }
        if cardWeight > currentWeight { return "Upgrade" }
        return "Downgrade"
    }

    func signOut() {
        Task { try? await supabase.auth.signOut() }
    }

    func deleteAccount() {
        Haptics.selection()
        
        Task {
            do {
                // 1. Ensure you have a valid session
                guard let session = try? await supabase.auth.session else {
                    print("Error: User is not logged in.")
                    return
                }

                // 2. Pass the token explicitly in the headers
                // Note: Use the function name exactly as it appears in Supabase dashboard
                let response = try await supabase.functions.invoke(
                    "delete-user",
                    options: .init(
                        method: .post,
                        headers: [
                            "Authorization": "Bearer \(session.accessToken)"
                        ]
                    )
                )
                
                print("Successfully deleted account.")
                
                // 3. Clean up locally
                try await supabase.auth.signOut()
                
                await MainActor.run {
                    Haptics.success()
                    // self.isAuthenticated = false (Reset your app state)
                }
                
            } catch {
                print("Delete Account Error: \(error.localizedDescription)")
            }
        }
    }
    
}
//enum PlanTier: String, CaseIterable {
//    case free, pro, elite
//    
//    var displayName: String {
//        switch self {
//        case .free: return "Starter"
//        case .pro: return "Creator"
//        case .elite: return "Agency"
//        }
//    }
//    
//    var price: String {
//        switch self {
//        case .free: return "Free"
//        case .pro: return "$9.99/mo"
//        case .elite: return "$29.99/mo"
//        }
//    }
//}
//
//struct AccountView: View {
//    @State private var userEmail: String = "Loading..."
//    @State private var userName: String = "User"
//    @State private var userId: String = ""
//    @State private var userTier: String = "loading"
//    @State private var selectedPerkMessage: String? = nil
//    
//    @State private var isAnimating = false
//    @State private var showDeleteAlert = false
//    
//    @State private var isProcessingPayment = false
//    @State private var checkoutURL: URL?
//    @State private var showSafari = false
//    
//    // MARK: - Plan Configuration
//    private var currentPlanName: String {
//        switch userTier.lowercased() {
//        case "free": return "Starter"
//        case "pro": return "Creator"
//        case "elite": return "Agency"
//        default: return "Starter"
//        }
//    }
//    
//
//    private var planPrice: String {
//        switch userTier.lowercased() {
//        case "pro": return "$9.99/mo"
//        case "elite": return "$29.99/mo"
//        default: return "Free"
//        }
//    }
//    
//    var body: some View {
//        NavigationStack {
//            ZStack {
//                // MARK: - Background
//                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
//                
//                LinearGradient(colors: [.brandPurple.opacity(0.25), .clear],
//                               startPoint: .top,
//                               endPoint: .bottom)
//                    .ignoresSafeArea()
//
//                ScrollView(showsIndicators: false) {
//                    VStack(spacing: 25) {
//                        
//                        // MARK: - Profile Header
//                        VStack(spacing: 15) {
//                            ZStack {
//                                Circle()
//                                    .fill(Color.brandPurple.opacity(0.15))
//                                    .frame(width: 100, height: 100)
//                                    .blur(radius: 20)
//                                
//                                Image(systemName: "person.crop.circle.fill")
//                                    .font(.system(size: 80))
//                                    .foregroundStyle(Color.brandPurple.gradient)
//                            }
//                            .padding(.top, 20)
//                            
//                            VStack(spacing: 4) {
//                                Text(userName)
//                                    .font(.system(size: 28, weight: .bold, design: .rounded))
//                                Text(userEmail)
//                                    .font(.subheadline)
//                                    .foregroundColor(.secondary)
//                            }
//                        }
//                        .opacity(isAnimating ? 1 : 0)
//                        .offset(y: isAnimating ? 0 : 15)
//
//                        // MARK: - Subscription Card
////                        subscriptionCard
////                            .opacity(isAnimating ? 1 : 0)
////                            .offset(y: isAnimating ? 0 : 20)
////                            .animation(.spring().delay(0.1), value: isAnimating)
//                        
//                        // MARK: - Tier Carousel
//                        VStack(alignment: .leading, spacing: 15) {
//                            Text("Subscription Plans")
//                                .font(.system(.subheadline, design: .rounded, weight: .bold))
//                                .foregroundColor(.secondary)
//                                .padding(.horizontal, 24)
//                            
//                            ScrollView(.horizontal, showsIndicators: false) {
//                                HStack(spacing: 16) {
//                                    ForEach(PlanTier.allCases, id: \.self) { plan in
//                                        tierCard(for: plan)
//                                    }
//                                }
//                                .padding(.horizontal, 24)
//                                .scrollTargetLayout()
//                            }
//                            .scrollTargetBehavior(.viewAligned)
//                        }
//
//                            
//                           
//
//                        // MARK: - Settings Section
//                        VStack(spacing: 12) {
//                            accountActionRow(title: "Sign Out", icon: "rectangle.portrait.and.arrow.right", color: .primary) {
//                                Haptics.selection()
//                                signOut()
//                            }
//                            
//                            accountActionRow(title: "Delete Account", icon: "trash", color: .roseRed) {
//                                Haptics.selection()
//                                showDeleteAlert = true
//                            }
//                        }
//                        .padding(.horizontal)
//                        .opacity(isAnimating ? 1 : 0)
//                        .offset(y: isAnimating ? 0 : 25)
//                        .animation(.spring().delay(0.2), value: isAnimating)
//
//                        Text("User ID: \(userId.prefix(12))...")
//                            .font(.system(.caption2, design: .monospaced))
//                            .foregroundColor(.secondary.opacity(0.5))
//                            .padding(.top, 10)
//                    }
//                    .padding(.bottom, 30)
//                }
//                
//                
//                
//            
//                if let message = selectedPerkMessage {
//                    VStack {
//                        Spacer() // Pushes it to the bottom area
//                        
//                        HStack(spacing: 12) {
//                            Text(message)
//                                .font(.system(.subheadline, design: .rounded, weight: .medium))
//                                .foregroundColor(.white)
//                                .multilineTextAlignment(.leading)
//                                .fixedSize(horizontal: false, vertical: true)
//                            
//                            Button {
//                                withAnimation(.spring()) { selectedPerkMessage = nil }
//                            } label: {
//                                Image(systemName: "xmark.circle.fill")
//                                    .foregroundColor(.white.opacity(0.6))
//                                    .font(.system(size: 20))
//                            }
//                        }
//                        .padding(.horizontal, 16)
//                        .padding(.vertical, 14)
//                        .background(
//                            RoundedRectangle(cornerRadius: 16)
//                                .fill(Color.brandPurple.opacity(0.9))
//                                .overlay(
//                                    RoundedRectangle(cornerRadius: 16)
//                                        .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
//                                )
//                        )
//                        .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 10)
//                        .padding(.horizontal, 24)
//                        .padding(.bottom, 100) // Changed from 50 to 100 to move it UP
//                    }
//                    .zIndex(100) // This is CRITICAL
//                    .transition(.asymmetric(
//                        insertion: .move(edge: .bottom).combined(with: .opacity),
//                        removal: .opacity.combined(with: .scale(scale: 0.9))
//                    ))
//                }
//                
//                
//                
//                
//                
//                
//            }
//            .navigationTitle("")
//            .navigationBarHidden(true)
//            .alert("Delete Account", isPresented: $showDeleteAlert) {
//                Button("Cancel", role: .cancel) { }
//                Button("Delete", role: .destructive) { deleteAccount() }
//            } message: {
//                Text("This action is permanent and will remove all your scheduled posts.")
//            }
//            .onAppear {
//                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
//                    isAnimating = true
//                }
//            }
//            .task {
//                await fetchUserData()
//                self.userTier = await getCurrentTier()
//            }
//            
//            
//          
//
//            
//            
//            
//            
//            
//        }
//        .onTapGesture {
//            // Dismiss tooltip if user taps anywhere else on the screen
//            if selectedPerkMessage != nil {
//                withAnimation { selectedPerkMessage = nil }
//            }
//        }
//        .sheet(isPresented: $showSafari) {
//            if let url = checkoutURL {
//                SafariView(url: url)
//                    .ignoresSafeArea()
//            }
//        }
//    }
//
//    // MARK: - Subcomponents
//    
//    private var subscriptionCard: some View {
//        VStack(alignment: .leading, spacing: 16) {
//            // Plan Header
//            HStack {
//                VStack(alignment: .leading, spacing: 4) {
//                    Text(currentPlanName)
//                        .font(.caption.bold())
//                        .foregroundColor(.brandPurple)
//                        .textCase(.uppercase)
//                    Text(planPrice)
//                        .font(.title2.bold())
//                }
//                Spacer()
//                Image(systemName: userTier.lowercased() == "free" ? "leaf.fill" : "crown.fill")
//                    .font(.title)
//                    .foregroundStyle( AnyShapeStyle(Color.brandPurple.gradient)
//                    )
//            }
//            
//            Divider().background(Color.brandPurple.opacity(0.2))
//
//            // MARK: - Feature List Based on Business Model
//            VStack(alignment: .leading, spacing: 12) {
//                if userTier.lowercased() == "free" {
//                    perkRow(icon: "number.circle.fill", text: "10 Posts per Month", isLimit: true)
//                    perkRow(icon: "clock.badge.exclamationmark", text: "No Scheduling (Instant only)", isLimit: true)
//                    perkRow(icon: "square.dashed", text: "Watermarked Videos", isLimit: true)
//                    perkRow(icon: "tag.fill", text: "Branded Captions", isLimit: true)
//                    perkRow(icon: "network", text: "Post to 3 Platforms",
//                        isLimit: true)
//                } else if userTier.lowercased() == "pro" {
//                    perkRow(icon: "infinity", text: "Unlimited Posts")
//                    perkRow(icon: "calendar.badge.plus", text: "Full Scheduling Access")
//                    perkRow(icon: "checkmark.seal.fill", text: "No Watermarks")
//                    perkRow(icon: "tag.fill", text: "Branded Captions", isLimit: true)
//                    perkRow(icon: "network", text: "Post to 5 Platforms", isLimit: true)
//                } else if userTier.lowercased() == "elite" {
//                    // Elite Tier
//                    perkRow(icon: "infinity", text: "Unlimited Posts")
//                    perkRow(icon: "calendar.badge.plus", text: "Full Scheduling Access")
//                    perkRow(icon: "sparkles", text: "No Watermarks or Branding")
//                    perkRow(icon: "globe", text: "All Platforms Enabled")
//                    perkRow(icon: "bolt.fill", text: "Priority Support")
//                }
//            }
//
//            // Action Button
//            Button {
//                Haptics.success()
//                // Action to open Paywall
//            } label: {
//                Text(userTier.lowercased() == "elite" ? "Manage Plan" : "Upgrade Now")
//                    .font(.headline)
//                    .foregroundColor(.white)
//                    .frame(maxWidth: .infinity)
//                    .padding()
//                    .background(userTier.lowercased() == "elite" ? Color.secondary : Color.brandPurple)
//                    .clipShape(RoundedRectangle(cornerRadius: 15))
//            }
//            .padding(.top, 5)
//        }
//        .padding(20)
//        .background(
//            RoundedRectangle(cornerRadius: 24)
//                .fill(.ultraThinMaterial)
//                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
//        )
//        .padding(.horizontal)
//    }
//    @ViewBuilder
//    func accountActionRow(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
//        Button(action: action) {
//            HStack {
//                Image(systemName: icon)
//                    .foregroundColor(color)
//                    .frame(width: 25)
//                Text(title)
//                    .font(.system(.body, design: .rounded, weight: .semibold))
//                    .foregroundColor(color)
//                Spacer()
//                Image(systemName: "chevron.right")
//                    .font(.caption)
//                    .foregroundColor(.secondary)
//            }
//            .padding()
//            .background(RoundedRectangle(cornerRadius: 18).fill(.ultraThinMaterial))
//        }
//        .buttonStyle(.plain)
//    }
//
//    // MARK: - Logic
//    
//    func fetchUserData() async {
//        if let session = try? await supabase.auth.session {
//            self.userEmail = session.user.email ?? "No Email"
//            self.userId = session.user.id.uuidString
//            
//            // Fetch name and tier from your profiles table
//            do {
//                let profile: UserProfile = try await supabase
//                    .from("profiles")
//                    .select()
//                    .eq("id", value: session.user.id)
//                    .single()
//                    .execute()
//                    .value
//                
//                await MainActor.run {
//                    self.userName = profile.username
//                    //self.userTier = profile.tier
//                    
//                }
//            } catch {
//                print("Profile fetch error: \(error)")
//            }
//        }
//    }
//    
//    
//    
//    
//    @ViewBuilder
//    private func perkRow(icon: String, text: String, isLimit: Bool = false, detailMessage: String? = nil) -> some View {
//        HStack(spacing: 12) {
//            Image(systemName: icon)
//                .font(.system(size: 14, weight: .semibold))
//                .foregroundColor(isLimit ? .secondary.opacity(0.8) : .brandPurple)
//                .frame(width: 24)
//            
//            Text(text)
//                .font(.system(size: 14, weight: .medium, design: .rounded))
//                .foregroundColor(isLimit ? .secondary : .primary)
//                
//            Spacer()
//            
//            if isLimit, let message = detailMessage {
//                Button {
//                    Haptics.selection() // Gentle haptic for "info"
//                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
//                        selectedPerkMessage = message
//                    }
//                } label: {
//                    Image(systemName: "info.circle")
//                        .font(.caption)
//                        .foregroundColor(.brandPurple.opacity(0.6))
//                        .contentShape(Rectangle()) // Makes it easier to tap
//                }
//                .buttonStyle(.plain)
//                .highPriorityGesture(TapGesture().onEnded {
//                        // This forces the tap to be recognized even if the ScrollView is active
//                        Haptics.selection()
//                        withAnimation(.spring()) {
//                            selectedPerkMessage = message
//                        }
//                    })
//            }
//        }
//    }
//    
//    
//    
//    @ViewBuilder
//    private func tierCard(for plan: PlanTier) -> some View {
//        let isCurrentPlan = userTier.lowercased() == plan.rawValue
//        let tierWeights: [String: Int] = ["free": 0, "pro": 1, "elite": 2]
//        let currentWeight = tierWeights[userTier.lowercased()] ?? 0
//        let cardWeight = tierWeights[plan.rawValue] ?? 0
//        
//        VStack(alignment: .leading, spacing: 16) {
//            // Status Badge
//            HStack {
//                Text(plan.displayName)
//                    .font(.caption.bold())
//                    .foregroundColor(isCurrentPlan ? .white : .brandPurple)
//                    .padding(.horizontal, 10)
//                    .padding(.vertical, 4)
//                    .background(isCurrentPlan ? Color.brandPurple : Color.brandPurple.opacity(0.1))
//                    .clipShape(Capsule())
//                
//                Spacer()
//                
//                if isCurrentPlan {
//                    Text("Current")
//                        .font(.caption2.bold())
//                        .foregroundColor(.secondary)
//                }
//            }
//            
//            VStack(alignment: .leading, spacing: 4) {
//                Text(plan.price)
//                    .font(.system(size: 28, weight: .bold, design: .rounded))
//                Text("Billed monthly")
//                    .font(.caption)
//                    .foregroundColor(.secondary)
//            }
//            
//            Divider().background(Color.brandPurple.opacity(0.2))
//            
//            // Features
//            VStack(alignment: .leading, spacing: 10) {
//                if plan == .free {
//                    perkRow(
//                        icon: "number.circle.fill",
//                        text: "10 Posts per Month",
//                        isLimit: true,
//                        detailMessage: "The Starter plan allows for 10 total posts across all platforms every 30 days.")
//                    perkRow(
//                        icon: "clock.badge.exclamationmark",
//                        text: "No Scheduled Posts",
//                        isLimit: true,
//                        detailMessage: "Scheduling is a premium feature. Starter users can only publish posts immediately."
//                    )
//                    perkRow(
//                        icon: "square.dashed",
//                        text: "Watermarked Videos",
//                        isLimit: true,
//                        detailMessage: "Videos exported on the free tier include a small watermark."
//                    )
//                    perkRow(
//                        icon: "tag.fill",
//                        text: "Branded Captions",
//                        isLimit: true,
//                        detailMessage: "Captions on the free tier include 'Sent via UniPost on iOS' with UniPost tags to support our community."
//                    )
//                    perkRow(
//                        icon: "network",
//                        text: "Post to 3 Platforms",
//                        isLimit: true,
//                        detailMessage: "Connect up to 3 social accounts."
//                    )
//
//                } else if plan == .pro {
//                    perkRow(icon: "infinity", text: "Unlimited Posts")
//                    perkRow(icon: "calendar.badge.plus", text: "Full Scheduling Access")
//                    perkRow(icon: "checkmark.seal.fill", text: "No Watermarks")
//                    perkRow(
//                        icon: "tag.fill",
//                        text: "Branded Captions",
//                        isLimit: true,
//                        detailMessage: "Captions on the free tier includes 'Sent via UniPost on iOS' with UniPost tags to support our community."
//                    )
//                    perkRow(
//                        icon: "network",
//                        text: "Post to 5 Platforms",
//                        isLimit: true,
//                        detailMessage: "Connect up to 3 social accounts."
//                    )
//                } else {
//                    perkRow(icon: "infinity", text: "Unlimited Posts")
//                    perkRow(icon: "calendar.badge.plus", text: "Full Scheduling Access")
//                    perkRow(icon: "sparkles", text: "No Watermarks or Branding")
//                    perkRow(icon: "globe", text: "All Platforms Enabled")
//                    perkRow(icon: "bolt.fill", text: "Priority Support")
//                }
//            }
//            
//            Spacer(minLength: 20)
//            
//            // Action Button
//            
//            
//            Button {
//                if !isCurrentPlan {
//                    Task {
//                        await MainActor.run { isProcessingPayment = true }
//                        do {
//                            if let url = try await StripeService.shared.createCheckoutSession(tier: plan.rawValue) {
//                                await MainActor.run {
//                                    self.checkoutURL = url
//                                    self.showSafari = true
//                                    print(" url : \(url)")
//                                }
//                            
//                        } catch {
//                            print("Stripe Error: \(error.localizedDescription)")
//                        }
//                        await MainActor.run { isProcessingPayment = false }
//                    }
//                    Haptics.success()
//                    // might change order
//                }
//            } label: {
//                if isProcessingPayment && !isCurrentPlan {
//                    ProgressView().tint(.white)
//                } else {
//                    Text(buttonText(isCurrent: isCurrentPlan, currentWeight: currentWeight, cardWeight: cardWeight))
//                        .font(.system(.callout, design: .rounded, weight: .bold))
//                        .foregroundColor(isCurrentPlan ? .brandPurple : .white) // Purple text for current, White for actions
//                        .frame(maxWidth: .infinity)
//                        .padding(.vertical, 12)
//                        .background(isCurrentPlan ? Color.clear : Color.brandPurple) // Clear for current, Purple for actions
//                        .overlay(
//                            RoundedRectangle(cornerRadius: 12)
//                                .stroke(isCurrentPlan ? Color.brandPurple.opacity(0.3) : Color.clear, lineWidth: 1.5)
//                        )
//                        .clipShape(RoundedRectangle(cornerRadius: 12))
//                }
//                
//            }
//            .disabled(isProcessingPayment)
//            
//            
//            
//        }
//        .padding(20)
//        .frame(width: 280, height: 380) // Fixed size for consistent swiping
//        .background(
//            RoundedRectangle(cornerRadius: 24)
//                .fill(.ultraThinMaterial)
//                .overlay(
//                    RoundedRectangle(cornerRadius: 24)
//                        .stroke(isCurrentPlan ? Color.brandPurple.opacity(0.5) : Color.white.opacity(0.2), lineWidth: 2)
//                )
//        )
//        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
//    }
//
//
//
//
//    
//    func buttonText(isCurrent: Bool, currentWeight: Int, cardWeight: Int) -> String {
//        if isCurrent { return "Current Plan" }
//        if cardWeight > currentWeight { return "Upgrade" }
//        return "Downgrade"
//    }
//    
//    
//    
//    func signOut() {
//        Task { try? await supabase.auth.signOut() }
//    }
//    
//    func deleteAccount() {
//        // Here you would call your backend to wipe the user's data
//        Haptics.success()
//        print("Deleting account...")
//    }
//}
//
//

//
//  UploadView.swift
//  xPost
//
//  Created by Takekuni Tanemori on 1/3/26.
//

import SwiftUI

struct UploadView: View {
    @Binding var activeTab: Tab
    @State private var userTier: String = "loading"
    @State private var monthlyPostCount: Int = 0
    @State private var isShowingUpgradeSheet: Bool = false
    
    @State private var showCreateVideoSheet = false
    @State private var showCreatePhotoSheet = false
    @State private var animateItems = false
    @State private var bounceTrigger = 0
    @State private var animationPhase: Int = 0
    
    private var canUpload: Bool {
        if userTier.lowercased() == "free" {
            return monthlyPostCount < 10
        }
        return true
    }
    
    func loadUserData() async {
        self.userTier = await getCurrentTier()
        do {
            let count = try await PostService.shared.fetchMonthlyPostCount()
            await MainActor.run {
                self.monthlyPostCount = count
            }
        } catch {
            print("Error loading upload limits: \(error)")
        }
    }
    
    
    func startAnimations() {
        animationPhase = 0
        animateItems = false
        withAnimation(.easeOut(duration: 0.6)) {
            animationPhase = 1
            animateItems = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeOut(duration: 0.6)) {
                animationPhase = 2
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeOut(duration: 0.6)) {
                animationPhase = 3
            }
        }
    }

    
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Upload")
                .font(.system(size: 34, weight: .bold, design: .rounded))
           
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.top, 24)
        .opacity(animationPhase >= 1 ? 1 : 0)
        .offset(y: animationPhase >= 1 ? 0 : 20)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundColor(.secondary)
            .tracking(1.2)
            .padding(.horizontal, 24)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [.brandPurple.opacity(0.25), .clear],
                               startPoint: .top,
                               endPoint: .bottom)
                    .ignoresSafeArea()

                ScrollView {
                    
                    
                    
                    
                    
                    
                    VStack(spacing: 25) {
                        headerSection
                            
                        // Illustration Section (Phase 2)
                        VStack(spacing: 25) {
                            ZStack {
                                Circle()
                                    .fill(Color.brandPurple.opacity(0.1))
                                    .frame(width: 160, height: 160)
                                Image(systemName: "plus.viewfinder")
                                    .font(.system(size: 70, weight: .thin))
                                    .foregroundColor(.brandPurple)
                                    .symbolEffect(.bounce, value: bounceTrigger)
                            }
                                
                            VStack(spacing: 8) {
                                Text("Ready to share?")
                                    .font(.system(.title, design: .rounded, weight: .bold))
                                Text("Choose your content type and reach all your platforms at once.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                            }
                        }
                        .opacity(animationPhase >= 2 ? 1 : 0)
                        .offset(y: animationPhase >= 2 ? 0 : 20)

                        // Action Cards (Phase 3)
                        VStack(spacing: 16) {
                            uploadActionCard(
                                title: "Video Post",
                                subtitle: "Share Reels, Shorts, or TikToks",
                                icon: "video.fill",
                                color: .brandPurple,
                                delay: 0.1
                            ) {
                                Haptics.selection()
                                showCreateVideoSheet = true
                            }
                            
                            // Picture (Placeholder)
                            uploadActionCard(
                                title: "Image Gallery",
                                subtitle: "Post photos and carousels",
                                icon: "photo.on.rectangle.angled",
                                color: .brandPurple.opacity(0.7),
                                delay: 0.2
                            ) {
                                Haptics.selection()
                                showCreatePhotoSheet = true
                            }
                            
                            // Text (Placeholder)
                            uploadActionCard(
                                title: "Thought / Update",
                                subtitle: "Share a text-only update",
                                icon: "text.quote",
                                color: .brandPurple.opacity(0.5),
                                delay: 0.3
                            ) {
                                Haptics.selection()
                                // Logic for text coming soon
                            }
                        }
                        .padding(.horizontal, 20)
                        .opacity(animationPhase >= 3 ? 1 : 0)
                        .offset(y: animationPhase >= 3 ? 0 : 20)
                        
                    }
                     
                    
                }
            }
            //.navigationTitle("Upload")
            .sheet(isPresented: $showCreateVideoSheet) {
                CreatePostView()
            }
            .sheet(isPresented: $showCreatePhotoSheet) {
                CreatePhotoPostView()
            }
            .onAppear {
                startAnimations()
                withAnimation(.easeOut(duration: 0.6)) {
                    animateItems = true
                }
                bounceTrigger += 1
            }
          
        }
//        .sheet(isPresented: $showCreateSheet) {
//            CreatePostView()
//        }
        // Added the Upgrade Sheet exactly like SocialConnectView
        .sheet(isPresented: $isShowingUpgradeSheet) {
            UpgradeTierView(currentTier: userTier, activeTab: $activeTab)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            startAnimations()
            bounceTrigger += 1
        }
        .task {
            await loadUserData()
        }
        
        
    }
    

    // MARK: - Action Card Component
//    @ViewBuilder
//    func uploadActionCard(title: String, subtitle: String, icon: String, color: Color, delay: Double, action: @escaping () -> Void) -> some View {
//        let isLocked = !canUpload
//        Button(action: action) {
//            if isLocked {
//                Haptics.error()
//                isShowingUpgradeSheet = true
//            } else {
//                HStack(spacing: 20) {
//                    ZStack {
//                        RoundedRectangle(cornerRadius: 12, style: .continuous)
//                            .fill(color.gradient)
//                            .frame(width: 50, height: 50)
//                        
//                        Image(systemName: icon)
//                            .foregroundColor(.white)
//                            .font(.title3)
//                    }
//                    
//                    VStack(alignment: .leading, spacing: 2) {
//                        Text(title)
//                            .font(.headline)
//                            .foregroundColor(.primary)
//                        
//                        Text(subtitle)
//                            .font(.caption)
//                            .foregroundColor(.secondary)
//                    }
//                    
//                    Spacer()
//                    
//                    Image(systemName: "chevron.right")
//                        .font(.caption.bold())
//                        .foregroundColor(.secondary.opacity(0.5))
//                }
//                .padding()
//                .background(.ultraThinMaterial)
//                .cornerRadius(16)
//                .overlay(
//                    RoundedRectangle(cornerRadius: 16)
//                        .stroke(Color.brandPurple.opacity(0.1), lineWidth: 1)
//                )
//                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
//            }
//            
//        }
//        .buttonStyle(PlainButtonStyle())
//        .opacity(animateItems ? 1 : 0)
//        .offset(y: animateItems ? 0 : 20)
//        .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(delay), value: animateItems)
//    }
    
    
    @ViewBuilder
    func uploadActionCard(title: String, subtitle: String, icon: String, color: Color, delay: Double, action: @escaping () -> Void) -> some View {
        let isLocked = !canUpload
        
        Button(action: {
            // --- 1. LOGIC BLOCK (Code goes here) ---
            if isLocked {
                Haptics.error()
                isShowingUpgradeSheet = true
            } else {
                action()
            }
        }) {
            // --- 2. VIEW BLOCK (Visuals go here) ---
            HStack(spacing: 20) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isLocked ? Color.gray.gradient : color.gradient)
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: isLocked ? "lock.fill" : icon)
                        .foregroundColor(.white)
                        .font(.title3)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(title)
                            .font(.headline)
                            .foregroundColor(isLocked ? .secondary : .primary)
                        
                        if isLocked {
                            Text("PRO")
                                .font(.system(size: 8, weight: .bold))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.brandPurple.opacity(0.2))
                                .foregroundColor(Color.brandPurple)
                                .cornerRadius(4)
                        }
                    }
                    
                    Text(isLocked ? "\(monthlyPostCount)/10 posts used this month" : subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isLocked ? Color.brandPurple.opacity(0.2) : Color.brandPurple.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .opacity(animateItems ? (isLocked ? 0.8 : 1.0) : 0)
        .offset(y: animateItems ? 0 : 20)
        .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(delay), value: animateItems)
    }
}
   

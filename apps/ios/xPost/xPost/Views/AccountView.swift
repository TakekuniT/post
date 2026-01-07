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
    @State private var userName: String = "User"
    @State private var userId: String = ""
    @State private var userTier: String = "loading"
    
    @State private var isAnimating = false
    @State private var showDeleteAlert = false
    
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
    
    var body: some View {
        NavigationStack {
            ZStack {
                // MARK: - Background
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
                
                LinearGradient(colors: [.brandPurple.opacity(0.25), .clear],
                               startPoint: .top,
                               endPoint: .bottom)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 25) {
                        
                        // MARK: - Profile Header
                        VStack(spacing: 15) {
                            ZStack {
                                Circle()
                                    .fill(Color.brandPurple.opacity(0.15))
                                    .frame(width: 100, height: 100)
                                    .blur(radius: 20)
                                
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.system(size: 80))
                                    .foregroundStyle(Color.brandPurple.gradient)
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

                        // MARK: - Subscription Card
                        subscriptionCard
                            .opacity(isAnimating ? 1 : 0)
                            .offset(y: isAnimating ? 0 : 20)
                            .animation(.spring().delay(0.1), value: isAnimating)

                        // MARK: - Settings Section
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

                        Text("User ID: \(userId.prefix(12))...")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.secondary.opacity(0.5))
                            .padding(.top, 10)
                    }
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .alert("Delete Account", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) { deleteAccount() }
            } message: {
                Text("This action is permanent and will remove all your scheduled posts.")
            }
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    isAnimating = true
                }
            }
            .task {
                await fetchUserData()
                self.userTier = await getCurrentTier()
            }
        }
    }

    // MARK: - Subcomponents
    
    private var subscriptionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Plan Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(currentPlanName)
                        .font(.caption.bold())
                        .foregroundColor(.brandPurple)
                        .textCase(.uppercase)
                    Text(planPrice)
                        .font(.title2.bold())
                }
                Spacer()
                Image(systemName: userTier.lowercased() == "free" ? "leaf.fill" : "crown.fill")
                    .font(.title)
                    .foregroundStyle( AnyShapeStyle(Color.brandPurple.gradient)
                    )
            }
            
            Divider().background(Color.brandPurple.opacity(0.2))

            // MARK: - Feature List Based on Business Model
            VStack(alignment: .leading, spacing: 12) {
                if userTier.lowercased() == "free" {
                    perkRow(icon: "number.circle.fill", text: "10 Posts per Month", isLimit: true)
                    perkRow(icon: "clock.badge.exclamationmark", text: "No Scheduling (Instant only)", isLimit: true)
                    perkRow(icon: "square.dashed", text: "Watermarked Videos", isLimit: true)
                    perkRow(icon: "tag.fill", text: "Branded Captions", isLimit: true)
                    perkRow(icon: "network", text: "Post to 3 Platforms",
                        isLimit: true)
                } else if userTier.lowercased() == "pro" {
                    perkRow(icon: "infinity", text: "Unlimited Posts")
                    perkRow(icon: "calendar.badge.plus", text: "Full Scheduling Access")
                    perkRow(icon: "checkmark.seal.fill", text: "No Watermarks")
                    perkRow(icon: "tag.fill", text: "Branded Captions", isLimit: true)
                    perkRow(icon: "network", text: "Post to 5 Platforms", isLimit: true)
                } else if userTier.lowercased() == "elite" {
                    // Elite Tier
                    perkRow(icon: "infinity", text: "Unlimited Posts")
                    perkRow(icon: "calendar.badge.plus", text: "Full Scheduling Access")
                    perkRow(icon: "sparkles", text: "No Watermarks or Branding")
                    perkRow(icon: "globe", text: "All Platforms Enabled")
                    perkRow(icon: "bolt.fill", text: "Priority Support")
                }
            }

            // Action Button
            Button {
                Haptics.success()
                // Action to open Paywall
            } label: {
                Text(userTier.lowercased() == "elite" ? "Manage Plan" : "Upgrade Now")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(userTier.lowercased() == "elite" ? Color.secondary : Color.brandPurple)
                    .clipShape(RoundedRectangle(cornerRadius: 15))
            }
            .padding(.top, 5)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
        )
        .padding(.horizontal)
    }
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

    // MARK: - Logic
    
    func fetchUserData() async {
        if let session = try? await supabase.auth.session {
            self.userEmail = session.user.email ?? "No Email"
            self.userId = session.user.id.uuidString
            
            // Fetch name and tier from your profiles table
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
                    //self.userTier = profile.tier
                    
                }
            } catch {
                print("Profile fetch error: \(error)")
            }
        }
    }
    
    
    
    
    @ViewBuilder
    private func perkRow(icon: String, text: String, isLimit: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                // Use purple for active perks, gray for limits/branding
                .foregroundColor(isLimit ? .secondary.opacity(0.8) : .brandPurple)
                .frame(width: 24)
            
            Text(text)
                .font(.system(size: 14,  weight: .medium, design: .rounded))
                .foregroundColor(isLimit ? .secondary : .primary)
                
            Spacer()
            
            if isLimit {
                Image(systemName: "info.circle")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.5))
            }
        }
    }
    
    
    
    
    
    
    func signOut() {
        Task { try? await supabase.auth.signOut() }
    }
    
    func deleteAccount() {
        // Here you would call your backend to wipe the user's data
        Haptics.success()
        print("Deleting account...")
    }
}





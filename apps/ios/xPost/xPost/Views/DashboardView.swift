//
//  DashboardView.swift
//  xPost
//
//  Created by Takekuni Tanemori on 1/3/26.
//

import SwiftUI

struct MainDashboardView: View {
    @State private var posts: [PostModel] = [] // Your data from backend
    @State private var isAnimating = false
    
    
    
    
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
    
    
    
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
                
                // Matches your premium gradient header
                LinearGradient(colors: [.brandPurple.opacity(0.25), .clear],
                               startPoint: .top, endPoint: .center)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {
                        headerSection
                        
                        // 1. PENDING SECTION (Progressive)
                        let pendingPosts = posts.filter { $0.status == "pending" }
                        if !pendingPosts.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                sectionLabel("In Progress")
                                ForEach(pendingPosts) { post in
                                    PendingPostCard(post: post)
                                }
                            }
                        }

                        // 2. COMPLETED/FAILED SECTION (Static Row)
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
                    }
                    .padding(.top, 20)
                }
            }
            .navigationBarHidden(true)
            .onAppear { isAnimating = true }
        }
    }
    
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
}

// MARK: - Premium Pending Card
struct PendingPostCard: View {
    let post: PostModel
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(post.caption ?? "Video Post")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                    HStack {
                        ForEach(post.platforms, id: \.self) { platform in
                            Image(platform) // Use your social assets
                                .resizable().frame(width: 14, height: 14)
                        }
                    }
                }
                Spacer()
                // Time-based label (or "Uploading...")
                Text("Approx. 2m left")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.brandPurple)
            }
            
            // Thin, sleek progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.brandPurple.opacity(0.1))
                    Capsule()
                        .fill(Color.brandPurple.gradient)
                        .frame(width: geo.size.width * 0.65) // Replace with real progress
                }
            }
            .frame(height: 6)
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 24).fill(.ultraThinMaterial))
        .padding(.horizontal)
    }
}

// MARK: - History Row
struct HistoryRow: View {
    let post: PostModel
    
    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(post.status == "published" ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: post.status == "published" ? "checkmark" : "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(post.status == "published" ? .green : .red)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(post.caption ?? "Completed Post")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                Text(post.status.capitalized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text("Yesterday") // Replace with formatted date
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 20).fill(.ultraThinMaterial))
        .padding(.horizontal)
    }
}

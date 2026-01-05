//
//  DashboardView.swift
//  xPost
//
//  Created by Takekuni Tanemori on 1/3/26.
//

import SwiftUI
import Supabase

import SwiftUI
import Supabase

struct MainDashboardView: View {
    @State private var userName: String = "User"
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Consistent UniPost Background
                LinearGradient(colors: [.brandPurple.opacity(0.25), .clear],
                               startPoint: .top,
                               endPoint: .bottom)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // MARK: - Premium Header
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Welcome back,")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundColor(.secondary)
                            Text(userName.split(separator: "@").first?.capitalized ?? "User")
                                .font(.system(.title, design: .rounded, weight: .bold))
                        }
                        
                        Spacer()
                        
                        // Profile Avatar with Gradient
                        ZStack {
                            Circle()
                                .fill(Color.brandPurple.gradient)
                                .frame(width: 44, height: 44)
                            Image(systemName: "person.fill")
                                .foregroundColor(.white)
                                .font(.system(size: 20))
                        }
                        .shadow(color: .brandPurple.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .padding(.horizontal, 25)
                    .padding(.top, 20)
                    .padding(.bottom, 10)

                    // MARK: - Content Feed
                    ScrollView {
                        VStack(spacing: 20) {
                            // Quick Stats or Greeting Card
                            HStack {
                                statItem(label: "Posts", value: "0")
                                Divider().frame(height: 30)
                                statItem(label: "Platforms", value: "5")
                                Divider().frame(height: 30)
                                statItem(label: "Reach", value: "--")
                            }
                            .padding()
                            .background(.ultraThinMaterial)
                            .cornerRadius(20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.brandPurple.opacity(0.1), lineWidth: 1)
                            )
                            
                            // Feed Section Header
                            HStack {
                                Text("Your Recent Activity")
                                    .font(.system(.headline, design: .rounded))
                                    .foregroundColor(.primary)
                                Spacer()
                                Button("View All") {}
                                    .font(.caption.bold())
                                    .foregroundColor(.brandPurple)
                            }
                            .padding(.horizontal, 5)

                            // Placeholder Card
                            VStack(spacing: 15) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 40))
                                    .foregroundColor(.brandPurple.opacity(0.5))
                                
                                Text("No posts yet. Start UniPosting!")
                                    .font(.system(.callout, design: .rounded))
                                    .foregroundColor(.secondary)
                                    .italic()
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 60)
                            .background(.ultraThinMaterial)
                            .cornerRadius(25)
                            .overlay(
                                RoundedRectangle(cornerRadius: 25)
                                    .stroke(Color.brandPurple.opacity(0.2), lineWidth: 1)
                            )
                        }
                        .padding(25)
                    }
                }
            }
            .navigationBarHidden(true) // Custom header looks cleaner
            .task {
                await fetchUserData()
            }
        }
    }
    
    // MARK: - Helper Components
    
    @ViewBuilder
    func statItem(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundColor(.brandPurple)
            Text(label)
                .font(.system(.caption2, design: .rounded))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
    }

    func fetchUserData() async {
        if let user = try? await supabase.auth.session.user {
            self.userName = user.email ?? "User"
        }
    }
}

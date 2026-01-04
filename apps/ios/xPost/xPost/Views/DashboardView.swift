//
//  DashboardView.swift
//  xPost
//
//  Created by Takekuni Tanemori on 1/3/26.
//

import SwiftUI
import Supabase

struct MainDashboardView: View {
    @State private var userName: String = "User"
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Header Section
                HStack {
                    VStack(alignment: .leading) {
                        Text("Welcome back,")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(userName)
                            .font(.title).bold()
                    }
                    Spacer()
                    
                    // Profile/Settings Icon
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .frame(width: 40, height: 40)
                        .foregroundColor(.blue)
                }
                .padding()

                // Placeholder for your xPost content
                List {
                    Section("Your Recent Posts") {
                        Text("No posts yet. Start xPosting!")
                            .foregroundColor(.secondary)
                            .italic()
                    }
                }
                .listStyle(.insetGrouped)

                Spacer()
                
                // Logout Button
                // Logout Button
                Button(role: .destructive) {
                    signOut()
                } label: {
                    if isLoading {
                        ProgressView()
                    } else {
                        Label("Sign Out", systemImage: "arrow.right.square")
                    }
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity) // Move the frame here
                .padding()
            }
            .navigationTitle("Dashboard")
            .task {
                await fetchUserData()
            }
        }
    }
    
    // Fetch basic user info from the session
    func fetchUserData() async {
        if let user = try? await supabase.auth.session.user {
            self.userName = user.email ?? "User"
        }
    }
    
    // Sign out logic
    func signOut() {
        Task {
            isLoading = true
            do {
                try await supabase.auth.signOut()
                // Note: Your ContentView listener will handle the UI switch!
            } catch {
                print("Error signing out: \(error.localizedDescription)")
            }
            isLoading = false
        }
    }
}

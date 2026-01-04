//
//  AccountView.swift
//  xPost
//
//  Created by Takekuni Tanemori on 1/3/26.
//
import SwiftUI

struct AccountView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Profile") {
                    Text("Email: user@example.com")
                }
                Section("Social Accounts") {
                    Button("Connect TikTok") {}
                    Button("Connect Instagram") {}
                    Button("Connect YouTube") {}
                    Button("Connect FaceBook") {}
                }
                Section {
                    Button("Sign Out", role: .destructive) {
                        // Call your signOut function here
                        print("Sign Out Button Clicked")
                    }
                }
            }
            .navigationTitle("Account")
        }
    }
}

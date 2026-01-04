//
//  UploadView.swift
//  xPost
//
//  Created by Takekuni Tanemori on 1/3/26.
//
import SwiftUI

struct UploadView: View {
    @State private var showCreateSheet = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Image(systemName: "video.badge.plus")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                VStack(spacing: 10) {
                    Text("Ready to share?")
                        .font(.title2).bold()
                    Text("Configure your video, caption, and platforms in one place.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                }
                
                Button(action: { showCreateSheet = true }) {
                    Label("Create New Post", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
            }
            .navigationTitle("Upload")
            // This is the "Pop-up" logic
            .sheet(isPresented: $showCreateSheet) {
                CreatePostView()
            }
        }
    }
}

//
//  UploadView.swift
//  xPost
//
//  Created by Takekuni Tanemori on 1/3/26.
//

import SwiftUI

struct UploadView: View {
    @State private var showCreateSheet = false
    @State private var animateItems = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [.brandPurple.opacity(0.25), .clear],
                               startPoint: .top,
                               endPoint: .bottom)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 25) {
                        // Header Illustration
                        ZStack {
                            Circle()
                                .fill(Color.brandPurple.opacity(0.1))
                                .frame(width: 160, height: 160)
                            
                            Image(systemName: "plus.viewfinder")
                                .font(.system(size: 70, weight: .thin))
                                .foregroundColor(.brandPurple)
                                .symbolEffect(.bounce, value: animateItems)
                        }
                        .padding(.top, 40)
                        
                        VStack(spacing: 8) {
                            Text("Ready to share?")
                                .font(.system(.title, design: .rounded, weight: .bold))
                            
                            Text("Choose your content type and reach all your platforms at once.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        .opacity(animateItems ? 1 : 0)
                        .offset(y: animateItems ? 0 : 10)

                        // Action Cards
                        VStack(spacing: 16) {
                            // Video (Active)
                            uploadActionCard(
                                title: "Video Post",
                                subtitle: "Share Reels, Shorts, or TikToks",
                                icon: "video.fill",
                                color: .brandPurple,
                                delay: 0.1
                            ) {
                                Haptics.selection()
                                showCreateSheet = true
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
                                // Logic for pictures coming soon
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
                    }
                }
            }
            .navigationTitle("Upload")
            .sheet(isPresented: $showCreateSheet) {
                CreatePostView()
            }
            .onAppear {
                withAnimation(.easeOut(duration: 0.6)) {
                    animateItems = true
                }
            }
        }
    }

    // MARK: - Action Card Component
    @ViewBuilder
    func uploadActionCard(title: String, subtitle: String, icon: String, color: Color, delay: Double, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 20) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(color.gradient)
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: icon)
                        .foregroundColor(.white)
                        .font(.title3)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
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
                    .stroke(Color.brandPurple.opacity(0.1), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(PlainButtonStyle())
        .opacity(animateItems ? 1 : 0)
        .offset(y: animateItems ? 0 : 20)
        .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(delay), value: animateItems)
    }
}

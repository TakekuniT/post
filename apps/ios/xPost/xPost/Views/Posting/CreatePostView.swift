//
//  CreatePostView.swift
//  xPost
//
//  Created by Takekuni Tanemori on 1/3/26.
//

import SwiftUI
import PhotosUI



struct CreatePostView: View {
    @Environment(\.dismiss) var dismiss
    
    @State private var description = ""
    @State private var caption = ""
    @State private var selectedPlatforms: Set<String> = []
    @State private var linkedPlatforms: Set<String> = [] // Data from Supabase
    @State private var isLoadingLinks = true
    
    @State private var selectedItem: PhotosPickerItem?
    @State private var isUploading = false
    
    @State private var isScheduled = false
    @State private var scheduleDate = Date().addingTimeInterval(3600)
    
    @State private var userTier: String = "loading"
    @State private var errorMessage = ""
    @State private var shakeOffset: CGFloat = 0
    @State private var showUpgradeHint = false
    
    
    let platforms = ["youtube", "instagram", "tiktok", "facebook", "linkedin"]
    let platformAssets = ["youtube": "youtube", "instagram": "instagram", "tiktok": "tiktok", "facebook": "facebook", "linkedin": "linkedin-in"]
    let apiService = APIService()
    
    func withErrorAnimation(_ action: () -> Void) {
        withAnimation(.default) {
            action()
        }
        // Shake sequence
        withAnimation(.default.repeatCount(3, autoreverses: true).speed(4)) {
            shakeOffset = 6
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            shakeOffset = 0
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [.brandPurple.opacity(0.25), .clear], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        SectionHeader(title: "Content", icon: "video.badge.plus")
                        videoSelector
                        
                        SectionHeader(title: "Publish To", icon: "paperplane.fill")
                        platformSelectionGrid
                        
                        SectionHeader(title: "Schedule", icon: "calendar.badge.clock")
                        scheduleToggle

                        SectionHeader(title: "Details", icon: "text.alignleft")
                        VStack(spacing: 16) {
                            customTextEditor(text: $caption, placeholder: "Enter a catchy caption...")
                            if selectedPlatforms.contains("youtube") {
                                    customTextEditor(text: $description, placeholder: "YouTube Description (optional)")
                                        .transition(.move(edge: .top).combined(with: .opacity)) // Adds a smooth slide-in effect
                                }
                        }
                        if !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(.red)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(12)
                                .padding(.horizontal)
                                .transition(.move(edge: .top).combined(with: .opacity))
                                // Apply the shake here!
                                .offset(x: shakeOffset)
                        }
                        

                        
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Configure Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { Haptics.selection(); dismiss() }.foregroundColor(.roseRed)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { Haptics.success(); handleUpload() }) {
                        Text("Post")
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(isUploading || selectedItem == nil || selectedPlatforms.isEmpty ? Color.gray.opacity(0.3) : Color.brandPurple)
                            .clipShape(Capsule())
                    }
                    .disabled(isUploading || selectedItem == nil || selectedPlatforms.isEmpty)
                }
            }
            .overlay {
                if isUploading {
                    ZStack {
                        Color.black.opacity(0.2).ignoresSafeArea()
                        VStack(spacing: 15) {
                            ProgressView().tint(.brandPurple).scaleEffect(1.5)
                            Text("Uploading...").font(.subheadline).fontWeight(.medium)
                        }
                        .padding(30)
                        .background(.ultraThinMaterial)
                        .cornerRadius(20)
                    }
                }
            }
            .task {
                self.userTier = await getCurrentTier()
                if let linked = try? await AuthService.shared.fetchLinkedPlatforms() {
                                    withAnimation(.spring()) {
                        self.linkedPlatforms = Set(linked)
                    }
                }
                self.isLoadingLinks = false
            }
        }
    }

    // MARK: - Subviews
    private var videoSelector: some View {
        PhotosPicker(selection: $selectedItem, matching: .videos) {
            VStack(spacing: 12) {
                Image(systemName: selectedItem == nil ? "video.fill" : "checkmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.brandPurple)
                    .scaleEffect(selectedItem == nil ? 1.0 : 1.2)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: selectedItem)
                
                Text(selectedItem == nil ? "Select Video File" : "Video Ready to Post")
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 30)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            // Branding-consistent purple glow instead of green
                            .stroke(selectedItem == nil ? Color.brandPurple.opacity(0.5) : Color.brandPurple, lineWidth: 2)
                            .shadow(color: .brandPurple.opacity(selectedItem == nil ? 0 : 0.6), radius: 12)
                    )
            )
            .scaleEffect(selectedItem == nil ? 1.0 : 1.03)
            .animation(.easeOut(duration: 0.5), value: selectedItem)
        }
        .simultaneousGesture(TapGesture().onEnded { Haptics.selection() })
    }
    
//    private var scheduleToggle: some View {
//        VStack(spacing: 12) {
//            Toggle("Schedule Post", isOn: $isScheduled.animation(.spring()))
//                .tint(.brandPurple)
//                .font(.system(.headline, design: .rounded))
//            
//            if isScheduled {
//                DatePicker(
//                    "Select Time",
//                    selection: $scheduleDate,
//                    in: Date()..., // Prevents selecting past dates
//                    displayedComponents: [.date, .hourAndMinute]
//                )
//                .datePickerStyle(.compact)
//                .tint(.brandPurple)
//                .transition(.move(edge: .top).combined(with: .opacity))
//            }
//        }
//        .padding()
//        .background(.ultraThinMaterial)
//        .cornerRadius(16)
//        .overlay(
//            RoundedRectangle(cornerRadius: 16)
//                .stroke(Color.brandPurple.opacity(0.4), lineWidth: 1.5)
//        )
//    }
//
    private var scheduleToggle: some View {
        let isFreeTier = userTier.lowercased() == "free"
        
        return VStack(spacing: 12) {
            HStack {
                Toggle(isOn: $isScheduled.animation(.spring())) {
                    HStack(spacing: 8) {
                        Text("Schedule Post")
                        if isFreeTier {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 12))
                                .foregroundColor(Color.brandPurple)
                        }
                    }
                }
                .tint(.brandPurple)
                .font(.system(.headline, design: .rounded))
                // This is the key: disable if free
                .disabled(isFreeTier)
                // Trigger upgrade sheet if they tap the disabled area
                .onTapGesture {
                    if isFreeTier {
                        Haptics.error()
                        withAnimation(.spring()) {
                            showUpgradeHint = true
                        }
                        // Auto-hide the hint after 3 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation { showUpgradeHint = false }
                        }
                    }
                }
            }
            
            if showUpgradeHint && isFreeTier {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundColor(.brandPurple)
                    Text("Upgrade to unlock scheduling")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.brandPurple)
                    Spacer()
                }
                .padding(.top, 4)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            if isScheduled && !isFreeTier {
                DatePicker(
                    "Select Time",
                    selection: $scheduleDate,
                    in: Date()...,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.compact)
                .tint(.brandPurple)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.brandPurple.opacity(isFreeTier ? 0.1 : 0.4), lineWidth: 1.5)
        )
        // Dim the whole section slightly if it's free tier
        .opacity(isFreeTier ? 0.6 : 1.0)
    }
    
    
    private var platformSelectionGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible(), spacing: 16)], spacing: 16) {
            ForEach(platforms, id: \.self) { platform in
                let isLinked = linkedPlatforms.contains(platform)
                PlatformCard(
                    platform: platform,
                    assetName: platformAssets[platform] ?? platform,
                    isSelected: selectedPlatforms.contains(platform),
                    
                    action: {
                        if isLinked {
                            Haptics.selection()
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                if selectedPlatforms.contains(platform) {
                                    selectedPlatforms.remove(platform)
                                } else {
                                    selectedPlatforms.insert(platform)
                                }
                            }
                        } else {
                            Haptics.error()
                        }
                    },
                    isLinked: isLinked
                )
                .padding(.horizontal, 4)
            }
        }
    }
    
    
    @ViewBuilder
    func SectionHeader(title: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon).foregroundColor(.brandPurple)
            Text(title).font(.system(.subheadline, design: .rounded)).fontWeight(.bold).textCase(.uppercase).foregroundColor(.secondary)
            Spacer()
        }
    }

    @ViewBuilder
    func customTextEditor(text: Binding<String>, placeholder: String) -> some View {
        ZStack(alignment: .topLeading) {
            if text.wrappedValue.isEmpty {
                Text(placeholder).foregroundColor(.primary.opacity(0.5)).padding(12)
            }
            TextEditor(text: text)
                .padding(8)
                .scrollContentBackground(.hidden)
                .background(Color.white.opacity(0.15))
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.brandPurple.opacity(0.5), lineWidth: 2))
        }
        .frame(height: 80)
    }

    // MARK: - Upload Logic
    func handleUpload() {
        let cleanCaption = ContentValidator.sanitize(caption)
        let cleanDesc = ContentValidator.sanitize(description)
        guard let selectedItem = selectedItem else { return }
                
        do {
            try ContentValidator.validate(caption: cleanCaption, description: cleanDesc, platforms: selectedPlatforms)
        } catch let error as PostError {
            Task { @MainActor in
                withErrorAnimation {
                    self.errorMessage = error.localizedDescription
                }
            }
            return
        } catch {
            withErrorAnimation {
                self.errorMessage = "Please check your inputs and try again."
            }
            return
        }
        isUploading = true

        Task {
            do {
                guard let session = try? await supabase.auth.session else {
                    isUploading = false
                    return
                }
                
                guard let movieData = try await selectedItem.loadTransferable(type: Data.self) else {
                    throw MediaError.corruptFile
                }
                
                try MediaValidator.validateVideo(data: movieData)
                
                let currentUserId = session.user.id.uuidString
                guard let movieData = try await selectedItem.loadTransferable(type: Data.self) else {
                    isUploading = false
                    return
                }
                
                let videoPath = try await apiService.uploadVideo(data: movieData, extension: "mp4")
                
                let newPost = Post(
                    user_id: currentUserId,
                    caption: caption,
                    description: description,
                    video_path: videoPath,
                    platforms: Array(selectedPlatforms),
                    scheduled_at: isScheduled ? scheduleDate : nil
                )
                
                await apiService.sendPost(post: newPost)
                isUploading = false
                dismiss()
            } catch {
                print("Upload Error: \(error)")
                isUploading = false
            }
        }
    }
}

// MARK: - Custom Component: Platform Card
struct PlatformCard: View {
    let platform: String
    let assetName: String
    let isSelected: Bool
    let action: () -> Void
    let isLinked: Bool
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(assetName)
                    .resizable()
                    .renderingMode(.template)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                
                Text(formatPlatformName(platform))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                
                Spacer()
                if !isLinked {
                    Image(systemName: "lock.fill")
                        .font(.system(size:10))
                        .foregroundColor(.secondary.opacity(0.6))
                } else if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity).animation(.spring(response: 0.5, dampingFraction: 0.6)),
                            removal: .opacity.animation(.easeOut(duration: 0.3))
                        ))
                }
//                if isSelected {
//                    Image(systemName: "checkmark.circle.fill")
//                        .transition(.asymmetric(
//                            insertion: .scale.combined(with: .opacity).animation(.spring(response: 0.5, dampingFraction: 0.6)),
//                            removal: .opacity.animation(.easeOut(duration: 0.3))
//                        ))
//                }
            }
            .padding(12)
            .background(isSelected ? Color.brandPurple : Color.brandPurple.opacity(0.05))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(12)
//            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.brandPurple.opacity(0.3), lineWidth: isSelected ? 0 : 1))
            .scaleEffect(isSelected ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(!isLinked)
    }
}

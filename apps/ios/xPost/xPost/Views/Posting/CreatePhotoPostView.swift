//
//  CreatePhotoPostView.swift
//  xPost
//
//  Created by Takekuni Tanemori on 1/12/26.
//

import SwiftUI
import PhotosUI

struct CreatePhotoPostView: View {
    @Environment(\.dismiss) var dismiss
    
    @State private var caption = ""
    @State private var selectedPlatforms: Set<String> = []
    @State private var linkedPlatforms: Set<String> = []
    @State private var isLoadingLinks = true
    
    // Multi-photo selection states
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    
    @State private var isUploading = false
    @State private var isScheduled = false
    @State private var scheduleDate = Date().addingTimeInterval(3600)
    
    @State private var userTier: String = "loading"
    @State private var errorMessage = ""
    @State private var shakeOffset: CGFloat = 0
    
    @State private var showUpgradeHint = false

    
    let platforms = ["instagram", "facebook", "linkedin"]
    let platformAssets = ["instagram": "instagram", "facebook": "facebook", "linkedin": "linkedin-in"]
    let apiService = APIService()

    var body: some View {
        NavigationStack {
            ZStack {
                backGround
                ScrollView {
                    contentStack
                }

                
            }
            .navigationTitle("New Photo Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    cancelButton
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    postButton
                }
            }
            .overlay {
                if isUploading {
                    loadingOverlay
                }
            }
            .onChange(of: selectedItems) { _ in
                loadSelectedPhotos()
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
    private var contentStack: some View {
        VStack(spacing: 24) {
            SectionHeader(title: "Photos", icon: "photo.badge.plus")
            photoSelector
            
            if !selectedImages.isEmpty {
                imagePreviewScroll
            }
            
            SectionHeader(title: "Publish To", icon: "paperplane.fill")
            platformSelectionGrid
            
            SectionHeader(title: "Schedule", icon: "calendar.badge.clock")
            scheduleToggle

            SectionHeader(title: "Details", icon: "text.alignleft")
            customTextEditor(text: $caption, placeholder: "What's on your mind? (Caption)")
            
            if !errorMessage.isEmpty {
                errorDisplay
            }
        }
        .padding(20)
        
    }
    private var postButton: some View {
        Button(action: { Haptics.success(); handleUpload() }) {
            Text("Post")
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(isUploading || selectedImages.isEmpty || selectedPlatforms.isEmpty ? Color.gray.opacity(0.3) : Color.brandPurple)
                .clipShape(Capsule())
        }
        .disabled(isUploading || selectedImages.isEmpty || selectedPlatforms.isEmpty)
    }
    
    private var cancelButton: some View {
        Button("Cancel") { Haptics.selection(); dismiss() }.foregroundColor(.roseRed)
    }
    private var backGround: some View {
        LinearGradient(colors: [.brandPurple.opacity(0.25), .clear], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }
    private var photoSelector: some View {
        PhotosPicker(selection: $selectedItems, maxSelectionCount: 10, matching: .images) {
            VStack(spacing: 12) {
                Image(systemName: selectedItems.isEmpty ? "photo.on.rectangle.angled" : "checkmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.brandPurple)
                    .scaleEffect(selectedItems.isEmpty ? 1.0 : 1.2)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: selectedItems.count)
//                Image(systemName: selectedImages.isEmpty ? "plus.viewfinder" : "photo.stack.fill")
//                    .font(.system(size: 32))
//                    .foregroundColor(.brandPurple)
//                
                Text(selectedImages.isEmpty ? "Select Photos" : "\(selectedImages.count) Photos Selected")
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
                            .stroke(selectedImages.isEmpty ? Color.brandPurple.opacity(0.5) : Color.brandPurple, lineWidth: 2)
                            .shadow(color: .brandPurple.opacity(selectedImages.isEmpty ? 0 : 0.6), radius: 12)
                    )
            )
        }
    }

    private var imagePreviewScroll: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(0..<selectedImages.count, id: \.self) { index in
                    Image(uiImage: selectedImages[index])
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .cornerRadius(12)
                        .overlay(
                            Button(action: {
                                selectedItems.remove(at: index)
                                selectedImages.remove(at: index)
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .background(Circle().fill(.white))
                                    .foregroundColor(.roseRed)
                            }
                            .offset(x: 35, y: -35)
                        )
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 10)
        }
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
                            if selectedPlatforms.contains(platform) {
                                selectedPlatforms.remove(platform)
                            } else {
                                selectedPlatforms.insert(platform)
                            }
                        } else {
                            Haptics.error()
                        }
                    },
                    isLinked: isLinked
                )
            }
        }
    }

    private var scheduleToggle: some View {
        let isFreeTier = userTier.lowercased() == "free"
        return VStack(spacing: 12) {
            Toggle(isOn: $isScheduled.animation(.spring())) {
                HStack {
                    Text("Schedule Post")
                    if isFreeTier { Image(systemName: "lock.fill").font(.caption).foregroundColor(.brandPurple) }
                }
            }
            .disabled(isFreeTier)
            .tint(.brandPurple)
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
                DatePicker("Select Time", selection: $scheduleDate, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.compact)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .opacity(isFreeTier ? 0.6 : 1.0)
        
        
        
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
    private func customTextEditor(text: Binding<String>, placeholder: String) -> some View {
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
        .frame(height: 100)
    }

    // MARK: - Logic Helpers

    private func loadSelectedPhotos() {
        selectedImages.removeAll()
        Task {
            for item in selectedItems {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    await MainActor.run {
                        selectedImages.append(uiImage)
                    }
                }
            }
        }
    }

    private func handleUpload() {
        
        let cleanCaption = ContentValidator.sanitize(caption)
        
        do {
            try ContentValidator.validate(caption: cleanCaption, description: "", platforms: selectedPlatforms)
            if selectedImages.isEmpty {
                throw PostError.emptyCaption
            }
            
        } catch let error as PostError {
            Task { @MainActor in
                withErrorAnimation {
                    self.errorMessage = error.localizedDescription
                }
            }
        } catch {
            withErrorAnimation {
                self.errorMessage = "An unexpected error occurred."
            }
            return
        }
        isUploading = true
        errorMessage = ""
        
        

        Task {
            do {
                guard let session = try? await supabase.auth.session else { throw PostError.authError }
                let currentUserId = session.user.id.uuidString
                
                var uploadedPaths: [String] = []
                
                // 1. Upload each image to Supabase Storage
                for image in selectedImages {
                    guard let imageData = image.jpegData(compressionQuality: 0.8) else { continue }
                    let path = try await apiService.uploadPhoto(data: imageData, extension: "jpg")
                    uploadedPaths.append(path)
                }
                
                // 2. Create the PhotoPost struct
                let photoPost = PhotoPost(
                    user_id: currentUserId,
                    caption: cleanCaption,
                    photo_paths: uploadedPaths,
                    platforms: Array(selectedPlatforms),
                    scheduled_at: isScheduled ? scheduleDate : nil
                )
                
                // 3. Send to Backend
                await apiService.sendPhotoPost(photoPost: photoPost)
                
                isUploading = false
                dismiss()
                
            } catch {
                withErrorAnimation {
                    self.errorMessage = error.localizedDescription
                }
                isUploading = false
            }
        }
    }
    
    // UI Utility components omitted for brevity but should be same as your original
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.2).ignoresSafeArea()
            VStack(spacing: 15) {
                ProgressView().tint(.brandPurple).scaleEffect(1.5)
                Text("Uploading Photos...").font(.subheadline).fontWeight(.medium)
            }
            .padding(30)
            .background(.ultraThinMaterial)
            .cornerRadius(20)
        }
    }
    
    private var errorDisplay: some View {
        Text(errorMessage)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundColor(.red)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.red.opacity(0.1))
            .cornerRadius(12)
            .offset(x: shakeOffset)
    }
    
    private func withErrorAnimation(_ action: () -> Void) {
        withAnimation(.default) { action() }
        withAnimation(.default.repeatCount(3, autoreverses: true).speed(4)) { shakeOffset = 6 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { shakeOffset = 0 }
    }
}

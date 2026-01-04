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
    
    // Form Data
    @State private var title = ""
    @State private var caption = ""
    @State private var selectedPlatforms: Set<String> = []
    
    // Video Selection
    @State private var selectedItem: PhotosPickerItem?
    @State private var isUploading = false
    
    let platforms = ["youtube", "instagram", "tiktok", "facebook", "linkedin"]
    let apiService = APIService()

    var body: some View {
        NavigationStack {
            Form {
                Section("Video Content") {
                    PhotosPicker(selection: $selectedItem, matching: .videos) {
                        Label(selectedItem == nil ? "Select Video" : "Video Selected ✅",
                              systemImage: "video.fill")
                    }
                }
                
                Section("Post Details") {
                    TextField("Title (YouTube only)", text: $title)
                    TextEditor(text: $caption)
                        .frame(height: 100)
                        .overlay(alignment: .topLeading) {
                            if caption.isEmpty {
                                Text("Enter caption...").foregroundColor(.gray).padding(7)
                            }
                        }
                }
                
                Section("Publish To") {
                    ForEach(platforms, id: \.self) { platform in
                        Toggle(platform.capitalized, isOn: Binding(
                            get: { selectedPlatforms.contains(platform) },
                            set: { isSelected in
                                if isSelected { selectedPlatforms.insert(platform) }
                                else { selectedPlatforms.remove(platform) }
                            }
                        ))
                    }
                }
            }
            .navigationTitle("Configure Post")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Send") {
                        handleUpload()
                    }
                    .disabled(isUploading || selectedItem == nil || selectedPlatforms.isEmpty)
                }
            }
            .overlay {
                if isUploading {
                    ProgressView("Uploading to Supabase...")
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(10)
                }
            }
        }
    }

    func handleUpload() {
        guard let selectedItem = selectedItem else { return }
        isUploading = true
        
        Task {
            do {
                // 1. Use try? to safely check for the session
                guard let session = try? await supabase.auth.session else {
                    print("No active session found")
                    isUploading = false
                    return
                }
                
                // 2. Now you can safely use session.user
                let currentUserId = session.user.id.uuidString

                // 1. Convert Picker Item to Data 
                guard let movieData = try await selectedItem.loadTransferable(type: Data.self) else { return }
                
                // 2. Upload to Supabase Storage
                let videoPath = try await apiService.uploadVideo(data: movieData, extension: "mp4")
                
                // 3. Create Post Object (Using a dummy user_id for now, link to Auth later)
                let newPost = Post(
                    user_id: currentUserId,
                    caption: caption,
                    title: title,
                    video_path: videoPath,
                    platforms: Array(selectedPlatforms)
                )
                
                // 4. Send to Python Backend
                apiService.sendPost(post: newPost)
                
                isUploading = false
                dismiss() // Close the pop-up
            } catch {
                print("Error during upload flow: \(error)")
                isUploading = false
            }
        }
    }
}

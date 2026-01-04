import SwiftUI
import PhotosUI



struct ContentView: View {
    @State private var isAuthenticated = false

    var body: some View {
        Group {
            if isAuthenticated {
                MainTabView()
            } else {
                NavigationStack {
                    LoginView(isAuthenticated: $isAuthenticated)
                }
            }
        }
        .task {
            // 1. Initial check for existing session on launch
            isAuthenticated = (try? await supabase.auth.session) != nil

            // 2. Listen for real-time auth state changes
            for await (event, session) in supabase.auth.authStateChanges {
                // Events include: .signedIn, .signedOut, .userDeleted, etc.
                if event == .signedIn {
                    isAuthenticated = true
                } else if event == .signedOut {
                    isAuthenticated = false
                }
            }
        }
    }
}
//struct ContentView: View {
//    @State private var caption: String = ""
//    @State private var title: String = ""
//    @State private var selectedItem: PhotosPickerItem? = nil
//    @State private var isUploading = false
//
//    @State private var postToYouTube = false
//    @State private var postToInstagram = false
//    @State private var postToTikTok = false
//    @State private var postToFacebook = false
//    
//    var body: some View {
//        NavigationView {
//            Form {
//                Section(header: Text("Video")) {
//                    PhotosPicker(selection: $selectedItem, matching: .videos) {
//                        HStack {
//                            Image(systemName: "video.badge.plus")
//                            Text("Select Video")
//                        }
//                    }
//                    if selectedItem != nil {
//                        Text("Video Selected").foregroundColor(.green)
//                    }
//                }
//
//                Section(header: Text("Content")) {
//                    TextField("Title (Youtube Short Only)", text: $title)
//                    TextEditor(text: $caption)
//                        .frame(height: 100)
//                }
//
//                Section(header: Text("Platforms")) {
//                    Toggle("YouTube", isOn: $postToYouTube)
//                    Toggle("Instagram", isOn: $postToInstagram)
//                    Toggle("TikTok", isOn: $postToTikTok)
//                    Toggle("Facebook", isOn: $postToFacebook)
//                }
//
//                Button(action: {
//                    Task {
//                        await handleUpload()
//                    }
//                }) {
//                    if isUploading {
//                        ProgressView()
//                    } else {
//                        Text("Publish Post")
//                    }
//                }
//                .disabled(isUploading || selectedItem == nil)
//            }
//            .navigationTitle("xPost")
//        }
//    }
//    
//    // THIS FUNCTION NOW HANDLES EVERYTHING
//    func handleUpload() async {
//        guard let item = selectedItem else { return }
//        isUploading = true
//        
//        do {
//            if let data = try await item.loadTransferable(type: Data.self) {
//                // --- ADDED THIS SECTION ---
//                let bcf = ByteCountFormatter()
//                bcf.allowedUnits = [.useMB] // Shows size in MB
//                bcf.countStyle = .file
//                let stringSize = bcf.string(fromByteCount: Int64(data.count))
//                
//                print("DEBUG: Final video data size: \(stringSize)")
//                print("DEBUG: Exact bytes: \(data.count)")
//                
//                if data.count > 50 * 1024 * 1024 {
//                    print("WARNING: This file is over 50MB and will likely be rejected by Supabase Free Tier.")
//                }
//                // ---------------------------
//                let ext = item.supportedContentTypes.first?.preferredFilenameExtension ?? "mp4"
//                let service = APIService()
//                
//                // 1. Upload to Supabase and get the path
//                let remotePath = try await service.uploadVideo(data: data, extension: ext)
//                
//                // 2. Prepare the platforms
//                var selectedPlatforms: [String] = []
//                if postToYouTube { selectedPlatforms.append("youtube") }
//                if postToInstagram { selectedPlatforms.append("instagram") }
//                if postToTikTok { selectedPlatforms.append("tiktok") }
//                if postToFacebook { selectedPlatforms.append("facebook") }
//                
//                // 3. Create the post using the remotePath found above
//                let post = Post(
//                    user_id: "ff95c9b9-c4ae-408c-a290-b04878d0d66a",
//                    caption: caption,
//                    title: title,
//                    video_path: remotePath,
//                    platforms: selectedPlatforms
//                )
//                
//                // 4. Send to Python
//                service.sendPost(post: post)
//                print("Successfully linked video: \(remotePath)")
//            }
//        } catch {
//            print("Error: \(error.localizedDescription)")
//        }
//        isUploading = false
//    }
//}

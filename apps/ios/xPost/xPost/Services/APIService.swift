//
//  APIService.swift
//  xPost
//
//  Created by Takekuni Tanemori on 1/3/26.
//

import Foundation
import Supabase

class APIService {
    // 127.0.0.1 is the 'local' address for the iOS Simulator
    let baseUrl = "http://127.0.0.1:8000"
    
    func sendPost(post: Post) {
        guard let url = URL(string: "\(baseUrl)/publish") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let jsonData = try JSONEncoder().encode(post)
            request.httpBody = jsonData
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("Error: \(error.localizedDescription)")
                    return
                }
                print("Successfully sent to backend!")
            }.resume()
            
        } catch {
            print("Failed to encode post")
        }
    }
    
    func uploadVideo(data: Data, extension ext: String) async throws -> String {
            // Create a unique name like "A1B2-C3D4.mp4"
            let fileName = "\(UUID().uuidString).\(ext)"
            
            let storage = supabase.storage.from("videos")
            
            // Upload the raw data
            try await storage.upload(
                fileName,          // No 'path:' label
                data: data,        // Changed from 'file:' to 'data:'
                options: FileOptions(contentType: "video/\(ext)")
            )
            
            return fileName // This is the 'file_path' for your Python backend
        }
}

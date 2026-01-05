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
    let baseUrl = "https://youlanda-migratory-trevor.ngrok-free.dev"
    
    
    
    func sendPost(post: Post) {
        guard let url = URL(string: "\(baseUrl)/publish") else {
            print("Invalid URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            
            let jsonData = try JSONEncoder().encode(post)
            
            // --- Print JSON for debugging ---
            // Print the JSON
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("Sending JSON:\n\(jsonString)") // <-- use backslash
            } else {
                print("Failed to convert JSON data to string")
            }

            
          
            // --- End debug print ---

            request.httpBody = jsonData

            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("Error: \(error.localizedDescription)")
                    return
                }

                if let httpResponse = response as? HTTPURLResponse {
                    print("Status code: \(httpResponse.statusCode)")
                }

                print("Successfully sent to backend!")
            }.resume()

        } catch {
            print("Failed to encode post: \(error.localizedDescription)")
        }
    }
    
    func uploadVideo(data: Data, extension ext: String) async throws -> String {
            let fileName = "\(UUID().uuidString).\(ext)"
            
            let storage = supabase.storage.from("videos")
            
            // Upload the raw data
            try await storage.upload(
                fileName,
                data: data,
                options: FileOptions(contentType: "video/\(ext)")
            )
            
            return fileName
        }
}

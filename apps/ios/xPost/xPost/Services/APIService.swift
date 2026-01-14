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
    
    // for development
    let baseUrl = "https://youlanda-migratory-trevor.ngrok-free.dev"
    
    // for production
    //let baseUrl = "https://post-production-3940.up.railway.app"
    
    
    
    func sendPost(post: Post) async {
        guard let url = URL(string: "\(baseUrl)/publish") else {
            print("Invalid URL")
            return
        }
        
        var sessionToken = ""
        do {
            let session = try await supabase.auth.session
            sessionToken = session.accessToken
        } catch {
            print("user is not logged in: \(error)")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(sessionToken)", forHTTPHeaderField: "Authorization")
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let jsonData = try encoder.encode(post)
            
            // --- Print JSON for debugging ---
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("Sending JSON:\n\(jsonString)") 
            } else {
                print("Failed to convert JSON data to string")
            }
            // --- End debug print ---
            request.httpBody = jsonData
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("Status code: \(httpResponse.statusCode)")
            }

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
    
    func uploadPhoto(data: Data, extension ext: String) async throws -> String {
        let fileName = "\(UUID().uuidString).\(ext)"
        let storage = supabase.storage.from("photos")
        
        try await storage.upload(
            fileName,
            data: data,
            options: FileOptions(contentType: "image/\(ext)")
        )
        
        return fileName
    }
    
    func sendPhotoPost(photoPost: PhotoPost) async {
        guard let url = URL(string: "\(baseUrl)/publish/photos") else {
            print("Invalid URL")
            return
        }
        
        var sessionToken = ""
        do {
            let session = try await supabase.auth.session
            sessionToken = session.accessToken
        } catch {
            print("user is not logged in: \(error)")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(sessionToken)", forHTTPHeaderField: "Authorization")
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let jsonData = try encoder.encode(photoPost)
            
            // --- Print JSON for debugging ---
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("Sending JSON:\n\(jsonString)")
            } else {
                print("Failed to convert JSON data to string")
            }
            // --- End debug print ---
            request.httpBody = jsonData
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("Status code: \(httpResponse.statusCode)")
            }

        } catch {
            print("Failed to encode post: \(error.localizedDescription)")
        }
    }
}

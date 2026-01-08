import Foundation
import Supabase

import Foundation
import Supabase

class PostService {
    static let shared = PostService()
    
//    func deletePost(id: Int) async throws {
//        try await supabase.database
//            .from("posts")
//            .delete()
//            .eq("id", value: id)
//            .execute()
//    }
    
    func deletePost(id: Int) async throws {
        let session = try await supabase.auth.session
        let userId = session.user.id

        try await supabase.database
            .from("posts")
            .delete()
            .eq("id", value: id)
            .execute()
    }
    
    func fetchUserPosts() async throws -> [PostModel] {
        let session = try await supabase.auth.session
        let userId = session.user.id

        let response = try await supabase
            .from("posts")
            .select()
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .execute()
        
        let decoder = JSONDecoder()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        
        // This handles Supabase's high-precision timestamps (microseconds)
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateStr = try container.decode(String.self)
            
            let formats = [
                "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ",
                "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
                "yyyy-MM-dd'T'HH:mm:ssZ"
            ]
            
            for format in formats {
                formatter.dateFormat = format
                if let date = formatter.date(from: dateStr) { return date }
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(dateStr)")
        }
        
        return try decoder.decode([PostModel].self, from: response.data)
    }
    
    
    func fetchMonthlyPostCount() async throws -> Int {
        let session = try await supabase.auth.session
        let userId = session.user.id
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: Date())
        guard let startOfMonth = calendar.date(from: components) else { return 0 }
        
        let formatter = ISO8601DateFormatter()
        let dateString = formatter.string(from: startOfMonth)

        // Explicitly define the response type
        let response = try await supabase
            .from("posts")
            .select("id", head: true, count: .exact)
            .eq("user_id", value: userId)
            .gte("created_at", value: dateString)
            .execute()
        
        // Optional binding to safely extract the count
        if let total = response.count {
            return total
        }
        
        return 0
    }
    
    
}




// Helper struct for decoding the count response
struct CountResponse: Codable {
    let count: Int
}

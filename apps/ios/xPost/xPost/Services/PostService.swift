import Foundation
import Supabase

import Foundation
import Supabase

class PostService {
    static let shared = PostService()
    
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
}

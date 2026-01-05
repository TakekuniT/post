import Foundation
import Supabase

class PostService {
    static let shared = PostService() // Singleton for easy access
    private let client = supabase // Uses your global supabase instance

    func fetchUserPosts() async throws -> [PostModel] {
        // 1. Get the current logged-in user's ID
        guard let userId = try? await client.auth.session.user.id else {
            return []
        }

        // 2. Fetch with a filter (.eq) to only get posts belonging to this user
        let posts: [PostModel] = try await client
            .from("posts")
            .select()
            .eq("user_id", value: userId) // Security: Filter by owner
            .order("created_at", ascending: false)
            .execute()
            .value
        
        return posts
    }
}

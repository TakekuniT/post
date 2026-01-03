import os
from supabase import create_client, Client

# Initialize Supabase
url: str = os.environ.get("SUPABASE_URL")
key: str = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
supabase: Client = create_client(url, key)

class UserManager:
    @staticmethod
    def get_social_tokens(user_id: str, platform: str):
        """Fetches tokens for a specific user and platform."""
        response = supabase.table("social_accounts") \
            .select("*") \
            .eq("user_id", user_id) \
            .eq("platform", platform) \
            .single() \
            .execute()
        return response.data

    @staticmethod
    def save_social_account(user_id: str, platform: str, data: dict):
        """Saves or updates tokens after a login/refresh."""
        return supabase.table("social_accounts").upsert({
            "user_id": user_id,
            "platform": platform,
            **data
        }).execute()
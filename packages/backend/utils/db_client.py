import os
from supabase import create_client, Client
from dotenv import load_dotenv
load_dotenv()

# Initialize Supabase
url: str = os.environ.get("SUPABASE_URL")
key: str = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
supabase: Client = create_client(url, key)

class UserManager:
    @staticmethod
    def get_social_tokens(user_id: str, platform: str):
        try:
            response = supabase.table("social_accounts") \
                .select("*") \
                .eq("user_id", user_id) \
                .eq("platform", platform) \
                .maybe_single() \
                .execute()
            
            return response.data # This will be a dict or None
        except Exception as e:
            print(f"Database Query Failed: {e}")
            return None
    # def get_social_tokens(user_id: str, platform: str):
    #     """Fetches tokens for a specific user and platform."""
    #     response = supabase.table("social_accounts") \
    #         .select("*") \
    #         .eq("user_id", user_id) \
    #         .eq("platform", platform) \
    #         .single() \
    #         .execute()
    #     if response.data:
    #         return response.data[0]
    #     return None

    @staticmethod
    def save_social_account(user_id: str, platform: str, data: dict):
        """Saves or updates tokens after a login/refresh."""
        return supabase.table("social_accounts").upsert({
            "user_id": user_id,
            "platform": platform,
            **data
        }, on_conflict="user_id,platform").execute()
    

    
    @staticmethod
    def update_social_account(user_id: str, platform: str, data: dict):
        """Updates tokens only for a specific user and platform."""
        return (
            supabase.table("social_accounts")
            .update(data)
            .eq("user_id", user_id)
            .eq("platform", platform)
            .execute()
        )
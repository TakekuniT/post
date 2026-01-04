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
    def save_social_account(user_id: str, platform: str, access_token: str, refresh_token: str, expires_at: str, platform_user_id):
        """Saves or updates tokens after a login/refresh."""
        return supabase.table("social_accounts").upsert({
            "user_id": user_id,
            "platform": platform,
            "platform_user_id": platform_user_id,
            "access_token": access_token,
            "refresh_token": refresh_token,
            "expires_at": expires_at,
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
    
    @staticmethod
    def delete_social_account(user_id: str, platform: str):
        """Deletes a social account and returns True if successful."""
        try:
            # We use .execute() and check if it actually removed something
            response = supabase.table("social_accounts") \
                .delete() \
                .eq("user_id", user_id) \
                .eq("platform", platform) \
                .execute()
            
            # If the response data is empty, it means nothing was deleted (already gone)
            return len(response.data) > 0
        except Exception as e:
            print(f"Database Delete Failed: {str(e)}")
            return False

    @staticmethod
    def get_all_user_accounts(user_id: str):
        """Returns a clean list of account dictionaries."""
        try:
            response = supabase.table("social_accounts") \
                .select("*") \
                .eq("user_id", user_id) \
                .execute()
            
            # Return the raw list of dictionaries (data)
            return response.data if response.data else []
        except Exception as e:
            print(f"Database Query Failed: {str(e)}")
            return []
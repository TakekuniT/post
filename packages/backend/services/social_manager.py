import os
from datetime import datetime, timedelta
from utils.db_client import supabase

class SocialManager:
    @staticmethod
    def save_oauth_connection(user_id, platform, token_data):
        """
        Parses raw token data from any platform and saves it to the DB.
        Token data is expected to be in the following format:
        {
            "access_token": access-token,
            "expires_in": expires-in-seconds,
            "open_id": open-id,
            "refresh_token": refresh-token,
            "scope": scope,
            "token_type": token-type
        }

        this function needs more work
        """
        # 1. Normalize the data based on platform quirks
        db_payload = {
            "access_token": token_data.get("access_token"),
            "refresh_token": token_data.get("refresh_token"),
            "platform_user_id": token_data.get("open_id") or token_data.get("instagram_id") or None,
            "updated_at": datetime.utcnow().isoformat()
        }

        # 2. Calculate Expiration
        expires_in = token_data.get("expires_in")
        if expires_in:
            db_payload["expires_at"] = (datetime.utcnow() + timedelta(seconds=expires_in)).isoformat()
        elif platform in ['facebook', 'instagram']:
            # Meta long-lived tokens default to 60 days if expires_in isn't present
            db_payload["expires_at"] = (datetime.utcnow() + timedelta(days=60)).isoformat()

        # 3. Upsert to Supabase
        return supabase.table("social_accounts").upsert(
            {
                "user_id": user_id,
                "platform": platform,
                **db_payload
            },
            on_conflict="user_id,platform"
        ).execute()
    
    
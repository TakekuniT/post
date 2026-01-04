import os
import requests
from datetime import datetime, timedelta, timezone
from utils.db_client import UserManager

class FacebookService:
    @staticmethod
    def get_valid_token(user_id: str):
        """
        Retrieves the Page Access Token. 
        Note: Page tokens are usually long-lived (60 days) or permanent 
        if derived from a long-lived User token.
        """
        account = UserManager.get_social_tokens(user_id, "facebook")
        if not account:
            raise Exception("Facebook account not linked.")

        # Standardizing timezone check as we did for TikTok/Instagram
        expires_at_str = account["expires_at"].replace('Z', '+00:00')
        expires_at = datetime.fromisoformat(expires_at_str)

        if datetime.now(timezone.utc) + timedelta(days=5) > expires_at:
            print(f"Refreshing Facebook token for {user_id}...")
            # Facebook refresh logic uses the same FB_EXCHANGE_TOKEN flow
            url = "https://graph.facebook.com/v19.0/oauth/access_token"
            params = {
                "grant_type": "fb_exchange_token",
                "client_id": os.getenv("FACEBOOK_CLIENT_ID"),
                "client_secret": os.getenv("FACEBOOK_CLIENT_SECRET"),
                "fb_exchange_token": account["access_token"]
            }
            res = requests.get(url, params=params).json()
            
            if "access_token" not in res:
                raise Exception(f"Facebook Refresh Failed: {res}")

            new_expiry = datetime.now(timezone.utc) + timedelta(seconds=res.get("expires_in", 5184000))
            UserManager.update_social_account(user_id, "facebook", {
                "access_token": res["access_token"],
                "expires_at": new_expiry.isoformat()
            })
            return res["access_token"], account["platform_user_id"]

        return account["access_token"], account["platform_user_id"]

    @staticmethod
    async def upload_video(user_id: str, file_path: str, caption: str):
        """
        High-Quality Resumable Upload Engine for Facebook Reels.
        """
        try:
            print(f"[FB Upload] Starting Facebook Reel upload...")
            token, page_id = FacebookService.get_valid_token(user_id)
            file_size = os.path.getsize(file_path)

            # --- PHASE 1: INITIALIZE (START) ---
            init_url = f"https://graph.facebook.com/v19.0/{page_id}/video_reels"
            init_res = requests.post(init_url, params={
                "upload_phase": "start",
                "access_token": token
            }).json()

            if "video_id" not in init_res:
                raise Exception(f"FB Init Failed: {init_res}")

            video_id = init_res["video_id"]
            upload_url = init_res["upload_url"]
            print(f"[FB Upload] Session started. Video ID: {video_id}")

            # --- PHASE 2: UPLOAD BYTES ---
            # Facebook Reels uses a binary POST to the upload_url
            with open(file_path, "rb") as f:
                headers = {
                    "Authorization": f"OAuth {token}",
                    "offset": "0",
                    "file_size": str(file_size),
                    "Content-Type": "application/octet-stream"
                }
                upload_res = requests.post(upload_url, data=f, headers=headers).json()

            if not upload_res.get("success"):
                raise Exception(f"FB Bytes Upload Failed: {upload_res}")
            print(f"[FB Upload] Bytes pushed successfully.")

            # --- PHASE 3: PUBLISH (FINISH) ---
            # This is where we set the caption and make it public
            publish_url = f"https://graph.facebook.com/v19.0/{page_id}/video_reels"
            publish_params = {
                "upload_phase": "finish",
                "video_id": video_id,
                "description": caption,
                "video_state": "PUBLISHED",
                "access_token": token
            }
            
            # Optional: Allow the video to be processed before finishing 
            # (FB is usually faster at ingest than Instagram)
            publish_res = requests.post(publish_url, params=publish_params).json()

            if not publish_res.get("success"):
                raise Exception(f"FB Finalize Failed: {publish_res}")

            print(f"[FB Upload] Success! Reel is live. ID: {video_id}")
            return video_id

        except Exception as e:
            print(f"[FB Service Error] {str(e)}")
            return None
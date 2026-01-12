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
            print(f"[FB Upload] upload_res: {upload_res}")
            print(f"[FB Upload] init_res: {init_res}")
            if not upload_res.get("success"):
                raise Exception(f"FB Bytes Upload Failed: {upload_res}")
            print(f"[FB Upload] Bytes pushed successfully.")
            print(f"[FB Upload] test link 4: https://www.facebook.com/permalink.php?story_fbid={video_id}&id={page_id}")
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
            #only works on browser: return {"platform": "facebook", "url": f"https://www.facebook.com/permalink.php?story_fbid={video_id}&id={page_id}"}
            # return {"platform": "facebook", "url": f"https://www.google.com/url?q=https://www.facebook.com/permalink.php?story_fbid={video_id}%26id={page_id}"}
            return {"platform": "facebook", "url": f"https://www.facebook.com/{page_id}/videos/{video_id}"}
        except Exception as e:
            print(f"[FB Service Error] {str(e)}")
            return None
        
    @staticmethod
    async def upload_photos(user_id: str, file_paths: list, caption: str):
        """
        Unified photo uploader. Handles 1 or more photos.
        Input 'file_paths' is strictly expected to be a list of strings.
        """
        try:
            print(f"[FB Photo] Starting upload for {len(file_paths)} item(s)...")
            token, page_id = FacebookService.get_valid_token(user_id)
            attached_media = []

            # --- PHASE 1: STAGE PHOTOS (UNPUBLISHED) ---
            # We upload images individually to get IDs before creating the final post.
            for path in file_paths:
                if not os.path.exists(path):
                    print(f"[FB Photo] File not found, skipping: {path}")
                    continue

                url = f"https://graph.facebook.com/v19.0/{page_id}/photos"
                with open(path, "rb") as f:
                    payload = {
                        "published": "false",  # Crucial: prevents individual posts for every photo
                        "access_token": token
                    }
                    files = {"source": f}
                    res = requests.post(url, data=payload, files=files).json()
                    
                    if "id" in res:
                        attached_media.append({"media_fbid": res["id"]})
                        print(f"[FB Photo] Staged: {res['id']}")
                    else:
                        print(f"[FB Photo] Failed to stage {path}: {res}")

            if not attached_media:
                raise Exception("No photos were successfully staged.")

            # --- PHASE 2: PUBLISH TO FEED ---
            # This creates a single post containing all staged photos.
            import json
            publish_url = f"https://graph.facebook.com/v19.0/{page_id}/feed"
            publish_payload = {
                "message": caption,
                "attached_media": json.dumps(attached_media),
                "access_token": token
            }
            
            publish_res = requests.post(publish_url, data=publish_payload).json()

            if "id" not in publish_res:
                raise Exception(f"FB Publish Failed: {publish_res}")

            post_id = publish_res["id"]
            print(f"[FB Photo] Success! Post ID: {post_id}")
            
            return {
                "platform": "facebook", 
                "url": f"https://www.facebook.com/{post_id}"
            }

        except Exception as e:
            print(f"[FB Service Error] {str(e)}")
            return None
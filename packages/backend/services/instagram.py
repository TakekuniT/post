import os
import requests
import time
from utils.db_client import UserManager
from datetime import datetime, timedelta, timezone

class InstagramService:
    @staticmethod
    def get_valid_token(user_id: str):
        """
        Ensures the Instagram Long-Lived token is still valid.
        If it's older than 45 days, we refresh it for another 60 days.
        """
        account = UserManager.get_social_tokens(user_id, "instagram")
        if not account:
            raise Exception("Instagram account not linked.")

        # 1. Check if the token needs refreshing
        # We refresh once it's within 15 days of expiring (45 days old)
        expires_at_str = account["expires_at"].replace('Z', '+00:00')
        expires_at = datetime.fromisoformat(expires_at_str)
        if datetime.now(timezone.utc) + timedelta(days=15) > expires_at:
            print(f"Instagram token for {user_id} is getting old. Refreshing...")

            # 2. Exchange old long-lived token for a NEW long-lived token
            # endpoint: GET /oauth/access_token
            url = "https://graph.facebook.com/v19.0/oauth/access_token"
            params = {
                "grant_type": "fb_exchange_token",
                "client_id": os.getenv("INSTAGRAM_CLIENT_ID"),
                "client_secret": os.getenv("INSTAGRAM_CLIENT_SECRET"),
                "fb_exchange_token": account["access_token"]
            }
            
            response = requests.get(url, params=params).json()
            
            if "access_token" not in response:
                raise Exception(f"Instagram Token Refresh Failed: {response}")

            # 3. Save the new 60-day token to Supabase
            # expires_in is usually 5184000 seconds (60 days)
            new_expiry = datetime.utcnow() + timedelta(seconds=response.get("expires_in", 5184000))
            
            update_data = {
                "access_token": response["access_token"],
                "expires_at": new_expiry.isoformat()
            }
            UserManager.save_social_account(user_id, "instagram", update_data)
            
            return response["access_token"], account["platform_user_id"]

        return account["access_token"], account["platform_user_id"]

    @staticmethod
    async def upload_video(user_id: str, file_path: str, caption: str):
        """
        High-Quality Resumable Upload for Instagram Reels.
        """
        try:
            token, ig_user_id = InstagramService.get_valid_token(user_id)
            file_size = os.path.getsize(file_path)

            # --- STEP 1: Create a Media Container ---
            # We tell Instagram we are sending a REEL
            init_url = f"https://graph.facebook.com/v19.0/{ig_user_id}/media"
            params = {
                "media_type": "REELS",
                "caption": caption,
                "upload_type": "resumable",
                "access_token": token
            }
            init_res = requests.post(init_url, params=params).json()
            
            if "id" not in init_res:
                raise Exception(f"Instagram Init Failed: {init_res}")
            
            container_id = init_res["id"]

            # --- STEP 2: Upload the Bytes (Resumable) ---
            # Instagram uses a specific 'rupload' host for pushing binaries
            upload_url = f"https://rupload.facebook.com/ig-api-upload/{container_id}"

            with open(file_path, "rb") as f:
                headers = {
                    "Authorization": f"Bearer {token}",
                    "offset": "0",
                    "file_size": str(file_size),
                    "Content-Type": "application/octet-stream"
                }
                response = requests.post(upload_url, data=f, headers=headers)
                upload_res = response.json()

            # Fix: Instagram resumable upload returns {'success': True} 
            # instead of {'status': 'success'}
            if not upload_res.get("success"):
                raise Exception(f"Instagram Bytes Upload Failed: {upload_res}")
            
            print("Bytes uploaded to Instagram. Starting processing wait...")


           
            # --- STEP 3: Wait for Processing ---
            # Instagram must process the video before it can be published.
            # We check the status every few seconds.
            
            
            status_url = f"https://graph.facebook.com/v19.0/{container_id}"
            max_retries = 30
            for _ in range(max_retries):
                check = requests.get(status_url, params={"fields": "status_code", "access_token": token}).json()
                status = check.get("status_code")
                
                if status == "FINISHED":
                    break
                elif status == "ERROR":
                    raise Exception("Instagram processing failed.")
                
                time.sleep(5)

            # --- STEP 4: Finalize & Publish ---
            publish_url = f"https://graph.facebook.com/v19.0/{ig_user_id}/media_publish"
            publish_res = requests.post(publish_url, params={
                "creation_id": container_id,
                "access_token": token
            }).json()

            print(f"Successfully posted to Instagram! Media ID: {publish_res.get('id')}")
            return publish_res.get("id")

        except Exception as e:
            print(f"Instagram Service Error: {str(e)}")
            return None